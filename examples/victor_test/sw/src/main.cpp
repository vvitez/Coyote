
#include <iostream>
#include <cstring>
#include <cstdlib>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <any>
// Coyote-specific includes
#include "cThread.hpp"

// Default vFPGA to assign cThreads to
#define DEFAULT_VFPGA_ID 0

int main()
{
    const int port = 12345;

    // create tcp socket
    int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd < 0)
    {
        perror("socket");
        return 1;
    }

    // set socket to reuse address so it can restart fast
    int opt = 1;
    if (setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0)
    {
        perror("setsockopt");
        close(listen_fd);
        return 1;
    }

    // define what we accept, so it's our port and any in address
    sockaddr_in serv_addr;
    std::memset(&serv_addr, 0, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_addr.s_addr = INADDR_ANY;
    serv_addr.sin_port = htons(port);

    // bind socket to our address and port
    if (bind(listen_fd, reinterpret_cast<sockaddr *>(&serv_addr), sizeof(serv_addr)) < 0)
    {
        perror("bind");
        close(listen_fd);
        return 1;
    }

    // start listening for 1 connection
    if (listen(listen_fd, 1) < 0)
    {
        perror("listen");
        close(listen_fd);
        return 1;
    }

    std::cout << "listening on port " << port << "..." << std::endl;

    // accept incoming connection
    sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);
    int conn_fd = accept(listen_fd, reinterpret_cast<sockaddr *>(&client_addr), &client_len);
    if (conn_fd < 0)
    {
        perror("accept");
        close(listen_fd);
        return 1;
    }

    std::cout << "got connection" << std::endl;

    const int BUF_SIZE = 1024; // store 1 dandelion sub packet
    char buffer[BUF_SIZE];
    int total_received = 0;

    // keep reading until we've got 1024 bytes or client closes connection, should only take 1 iteration
    while (total_received < BUF_SIZE)
    {
        int bytes_received = recv(conn_fd, buffer + total_received, BUF_SIZE - total_received, 0);
        if (bytes_received < 0)
        {
            perror("recv");
            close(conn_fd);
            close(listen_fd);
            return 1;
        }
        if (bytes_received == 0)
        {
            // client closed connection
            break;
        }
        total_received += bytes_received;
    }

    std::cout << "received " << total_received << " bytes:" << std::endl;
    // print received bytes
    std::cout.write(buffer, total_received);
    std::cout << std::endl;

    // coyote stuff

    std::unique_ptr<coyote::cThread<std::any>> coyote_thread(new coyote::cThread<std::any>(DEFAULT_VFPGA_ID, getpid(), 0));
    char *a = (char *)coyote_thread->getMem({coyote::CoyoteAlloc::HPF, BUF_SIZE});
    char *b = (char *)coyote_thread->getMem({coyote::CoyoteAlloc::HPF, BUF_SIZE}); // for receive
    if (!a || !b)
    {
        perror("Could not allocate memory for vectors, exiting...");
        close(conn_fd);
        close(listen_fd);
        return 1;
    }

    // fill a with buffer contents, i know it's dumbb, just for now
    for (int i = 0; i < BUF_SIZE; ++i)
    {
        a[i] = buffer[i];
    }
    coyote::sgEntry sg_a, sg_b;
    sg_a.local = {.src_addr = a, .src_len = BUF_SIZE, .src_dest = 0};
    sg_b.local = {.dst_addr = b, .dst_len = BUF_SIZE, .dst_dest = 0};
    std::cout << "sending out to coyote" << std::endl;
    coyote_thread->invoke(coyote::CoyoteOper::LOCAL_READ, &sg_a);
    coyote_thread->invoke(coyote::CoyoteOper::LOCAL_WRITE, &sg_b);
    while (
        coyote_thread->checkCompleted(coyote::CoyoteOper::LOCAL_WRITE) != 1 ||
        coyote_thread->checkCompleted(coyote::CoyoteOper::LOCAL_READ) != 2)
    { // twiddle thumbs
    }
    std::cout << "WE HEARD BACK FROM COYOTE WOOHOOO:" << std::endl;
    std::cout.write(b, total_received);
    std::cout << std::endl;
    // clean up and close sockets
    close(conn_fd);
    close(listen_fd);

    return 0;
}
