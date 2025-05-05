
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

    // create tcp socket

    const int BUF_SIZE = 1024; // store 1 dandelion sub packet
    char buffer[BUF_SIZE];
    size_t bytesRead = 0;

    {
        const char *filePath = "/home/vvitez/request_msg.bin";
        FILE *fp = std::fopen(filePath, "rb");
        if (!fp)
        {
            std::cerr << "Failed to open file: " << filePath << std::endl;
        }
        else
        {
            bytesRead = std::fread(buffer, 1, 1024, fp);
            if (bytesRead < 1024)
            {
                std::cerr << "File has fewer than 1024 bytes" << std::endl;
            }
            std::fclose(fp);
        }
    }

    std::cout << "found bytes" << std::endl;
    // std::cout.write(buffer, bytesRead);
    // std::cout << std::endl;

    // coyote stuff

    std::unique_ptr<coyote::cThread<std::any>> coyote_thread(new coyote::cThread<std::any>(DEFAULT_VFPGA_ID, getpid(), 0));
    char *a = (char *)coyote_thread->getMem({coyote::CoyoteAlloc::HPF, BUF_SIZE});
    char *b = (char *)coyote_thread->getMem({coyote::CoyoteAlloc::HPF, BUF_SIZE}); // for receive

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
        coyote_thread->checkCompleted(coyote::CoyoteOper::LOCAL_READ) != 1)
    { // twiddle thumbs
    }
    std::cout << "WE HEARD BACK FROM COYOTE WOOHOOO:" << std::endl;
    {
        FILE *fp = std::fopen("/home/vvitez/testoutput.bin", "wb");
        if (fp)
        {
            std::fwrite(b, 1, BUF_SIZE, fp);
            std::fclose(fp);
        }
        else
        {
            std::cerr << "Failed to open testoutput.bin for writing\n";
        }
    }

    return 0;
}
