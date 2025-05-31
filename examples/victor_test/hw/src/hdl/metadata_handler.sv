`include "axi_macros.svh"
import lynxTypes::*; 


//we want a type to be 128 bits to fit neatly in an axis_data_fifo entry.
typedef struct packed {
    logic [30:0] start_index; //pointer to where the data starts, 31 bits is for 2GB looping around
    logic [31:0] total_size; //total size of the data, could be smaller (29 bits for 512 MiB) but dandelion sends 32 bits anyways
    logic [15:0] bitstream_id; //also passed from dandelion
    logic [48:0] padding; //padding the rest to 128 bits 
} invocation_metatdata_t;

module metadata_handler (
    input logic     aclk,
    input logic     aresetn,

    //input "call"
    input logic         in_valid,
    output logic        in_ready,
    input logic         in_header, //was it a header packet
    input logic [31:0]  in_size,
    input_logic [31:0]  in_packet_data_size, //size of current packet data
    input logic [15:0]  in_bitstream_id,

    //output axi for finished entry
    output logic                    m_axis_tvalid,
    input  logic                    m_axis_tready,
    output invocation_metatdata_t   m_axis_tdata,

    //error signal if something illegal happened
    output logic error_out
);
    logic                entry_active;
    logic                push_pending; //means we push onto the queue next clk
    logic [30:0]         start_index;
    logic [31:0]         total_size;
    logic [31:0]         current_size;
    logic [15:0]         bitstream_id;

      assign in_ready = ~error_out && (in_header
                      ? (!entry_active && !push_pending)
                      : ( entry_active && !push_pending));
    //with special case for the header packet
    //this only is ready when there isn't a push happening, so we 
    //don't get confused and change the data from under the push
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
        entry_active    <= 1'b0;
        push_pending    <= 1'b0;
        start_index     <= '0;
        total_size    <= '0;
        current_size  <= '0;
        bitstream_id  <= '0;
        error_out       <= 1'b0;
        end else if (!error_out) begin
        // detect invalid header
        if (in_valid && in_header && entry_active) begin
            error_out <= 1'b1;
        end else begin
            if (in_valid && in_ready) begin
            if (in_header) begin
                //start a new entry, with initial packet data
                entry_active    <= 1'b1;
                total_size    <= in_size;
                bitstream_id  <= in_bitstream_id;
                current_size  <= in_packet_data_size;
                // if header beat contains whole packet, schedule push
                push_pending    <= (in_packet_data_size >= in_size);
            end else begin
                //accumulate  data
                current_size <= current_size + in_size;
                if (current_size + in_size >= total_size) begin
                push_pending <= 1'b1;
                end
            end
            end
            //on FIFO accept, clear entry and increase indedx
            if (push_pending && m_axis_tvalid && m_axis_tready) begin
            push_pending   <= 1'b0;
            entry_active   <= 1'b0;
            start_index    <= start_index + total_size;
            //clear error (state gated)
            error_out      <= 1'b0;
            end
        end
        end
        //on error_out, be dead
    end

//now the fifo writing, only when not error
assign m_axis_tvalid = ~error_out && push_pending;
assign m_axis_tdata.start_index = start_index;
assign m_axis_tdata.total_size  = total_size;
assign m_axis_tdata.bitstream_id = bitstream_id;
assign m_axis_tdata.padding = '0; 

//is this how ila is added?
ila_metadata inst_ila_metadata (
    .clk    (aclk),
    .probe0 (entry_active), //1 bit
    .probe1 (push_pending), //1 bit
    .probe2 (start_index), //31 bit
    .probe3 (total_size), //32 bit
    .probe4 (current_size), //32 bit
    .probe5 (bitstream_id), //16 bit
    .probe6 (error_out), //1 bit
    .probe7 (in_valid) //1 bit
  );