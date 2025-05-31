`timescale 1ns / 1ps


`include "axi_macros.svh"
import lynxTypes::*; 

module perf_local #(
  parameter int N_BEATS = 16    // 16×64B = 1024B packet
) (
  
  AXI4SR.s  axis_in,
  AXI4SR.m axis_out,

  input  logic   aclk,
  input  logic   aresetn
);

  // beat counter needs upper log2 of beats
  logic [$clog2(N_BEATS)-1:0] beat_cnt;
  // bitstream ID from beat 0
  logic [15:0] bitstream_id_r;

  // ready/valid forwarding
  assign axis_in.tready  = axis_out.tready;
  assign axis_out.tvalid = axis_in.tvalid;
  assign axis_out.tlast  = axis_in.tlast;

  // latch beat count & bitstream_id
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      beat_cnt       <= '0;
      bitstream_id_r <= '0;
    end else if (axis_in.tvalid && axis_in.tready) begin
      if (beat_cnt == 0)
        //get bitstream id in zeroeth beat
        bitstream_id_r <= axis_in.tdata[31:16];

      if (axis_in.tlast)
        beat_cnt <= '0;
      else
        beat_cnt <= beat_cnt + 1;
    end
  end

  // data path: header+passthrough or “+1” in 64-bit lanes
  always_comb begin
    // default passthrough
    axis_out.tdata = axis_in.tdata;

    if (bitstream_id_r == 16'h0001) begin
      if (beat_cnt == 0) begin
        // leave bytes [63:0] (8 B) untouched (flag 1, tile 1, id 2, size 4)
        // then for the remaining 56 bytes (bits 511:64) do +1 per 64-bit chunk
        for (int j = 0; j < 7; j++) begin
          axis_out.tdata[64 + j*64 +: 64] =
            axis_in.tdata[64 + j*64 +: 64] + 64'd1;
        end
      end
      else begin
        // beats 1–15: all eight 64-bit words get +1
        for (int i = 0; i < 8; i++) begin
          axis_out.tdata[i*64 +: 64] =
            axis_in.tdata[i*64 +: 64] + 64'd1;
        end
      end
    end
    // else: passthrough for other bitstreams
  end

endmodule
