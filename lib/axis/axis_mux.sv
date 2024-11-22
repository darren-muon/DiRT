//------------------------------------------------------------------------------
// File:    axis_mux.sv
//
// Author:  Darren Midkiff, Muon Space
// Credit:  This design is based heavily on axis_mux8.sv from Ian Buckley, Ion Concepts LLC
//
// Parameterizable:
// * arbitration scheme
//   - When in Round Robin mode, if current active port is N and there are M ports, 
//     the higest prioirty port for next transaction is (N+1) % M.
//     Transactions can be back to back.
//   - When in Priority mode, always transition back to IDLE after a transaction and burn 1 cycle. Port 0 is highest priority.
// * buffer mode (included small FIFO)
// * Width of datapath.
//
// Description:
// AXI Stream mux with no combinatorial through paths.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"

module axis_mux
  #(
    parameter NUM_INPUTS=8,  // Number of AXIS inputs
    parameter WIDTH=64,  // AXIS datapath width.
    parameter BUFFER=0,  // Add small FIFO on egress.
    parameter PRIORITY=0 // Default to Round Robin (0). Fixed Priority(1).
    )


   (
    input logic 	    clk,
    input logic 	    rst,
    //
    // Input Busses
    //
    input  [WIDTH-1:0] in_tdata  [NUM_INPUTS],
    input 	           in_tvalid [NUM_INPUTS],
    input              in_tlast  [NUM_INPUTS],
    output logic 		   in_tready [NUM_INPUTS],
    //
    // Output Bus
    //
    output [WIDTH-1:0] out_tdata,
    output  	         out_tvalid,
    output  	         out_tlast,
    input        	     out_tready
    );

   //
   // IDLE state for arbitration is MSB 1, LSBs all 0
   // Other states are integer value of the input index
   // (arb_state == 0 corresponds to selecting in_tdata[0])
   //
  localparam IDLE = 2**$clog2(NUM_INPUTS);

  reg [$clog2(NUM_INPUTS):0]             arb_state;

  logic [WIDTH-1:0]    out_tdata_fifo;
  logic                out_tlast_fifo;
  logic                out_tvalid_fifo;
  logic                out_tready_fifo;

  reg [WIDTH-1:0]      in_tdata_fifo;
  reg                  in_tvalid_fifo;
  reg                  in_tlast_fifo;
  logic                in_tready_fifo;


  //
  // 8 way combinatorial mux of the different inputs.
  //
  logic [$clog2(NUM_INPUTS)-1:0] sel;
  always_comb
    begin
      // Use default values to reduce code size - (hopefully no timing hit due to crap synth tools.)
      in_tready = '{default : '0};

      sel = arb_state[$clog2(NUM_INPUTS)-1:0];  // sel == 0 when arb_state == IDLE because the MSB is ignored
      in_tdata_fifo = in_tdata[sel];
      in_tvalid_fifo = in_tvalid[sel];
      in_tlast_fifo = in_tlast[sel];
      in_tready[sel] = in_tready_fifo;

    end // always (*)

  //
  //  Arbitration State Machine.
  //
  always_ff @(posedge clk) begin
    if(rst)
      arb_state <= IDLE;
    else

      // This is ugly, but I think it will synthesize correctly.
      // A for loop is used to create mutually exclusive if statements
      // testing arb_state, effectively creating a parameterized
      // case statement.
      // Nested for loops and breaks are used to create round-robin
      // prioritization.

      // CASE arb_state == IDLE
      if (arb_state == IDLE) begin
        if (in_tvalid[0]) begin
          // Go to 0 state unless this is a single-beat packet whose
          // beat is accepted in this cycle (when state is IDLE,
          // in_tready[0] = in_tready_fifo).
          arb_state <= in_tready_fifo && in_tlast[0] ? IDLE : '0;
        end else begin
          for (int val_i = 1; val_i < NUM_INPUTS; val_i++) begin
            if (in_tvalid[val_i]) begin
              arb_state <= val_i;
              break;
            end
          end
        end
      end

      // This loop unrolls to one conditional per input
      for (int case_i = 0; case_i < NUM_INPUTS; case_i++) begin
        // CASE arb_state == case_i
        if (arb_state == case_i) begin  
          if(in_tready_fifo && in_tvalid_fifo && in_tlast_fifo) begin
            arb_state <= IDLE;  // default state if no inputs waiting
            // This loop creates round-robin prioritization
            for (int val_i = case_i + 1; val_i < NUM_INPUTS + case_i; val_i++) begin
              if (in_tvalid[val_i % NUM_INPUTS]) begin
                arb_state <= val_i % NUM_INPUTS; // Modulo should evaluate at compile time and not be synthesized
                break;
              end
            end
          end
        end
      end
    end

   //
   // AXI minimal FIFO breaks all combinatorial through paths
   //
   axis_minimal_fifo #(.WIDTH(WIDTH+1)) axis_minimal_fifo_i0
     (
      .clk(clk),
      .rst(rst),
      .in_tdata({in_tlast_fifo,in_tdata_fifo}),
      .in_tvalid(in_tvalid_fifo),
      .in_tready(in_tready_fifo),
      .out_tdata({out_tlast_fifo,out_tdata_fifo}),
      .out_tvalid(out_tvalid_fifo),
      .out_tready(out_tready_fifo),
      // Status (unused)
      .space(),
      .occupied()
      );

   //
   // Optional small egress buffer FIFO to mitigate bursty contention.
   //
   generate
      if(BUFFER == 0)
        begin
           assign out_tdata = out_tdata_fifo;
           assign out_tlast = out_tlast_fifo;
           assign out_tvalid = out_tvalid_fifo;
           assign out_tready_fifo = out_tready;
        end
      else
        axis_fifo #(.WIDTH(WIDTH+1)) axis_fifo_short_i0
          (.clk(clk), .rst(rst),
           .in_tdata({out_tlast_fifo,out_tdata_fifo}), .in_tvalid(out_tvalid_fifo), .in_tready(out_tready_fifo),
           .out_tdata({out_tlast,out_tdata}), .out_tvalid(out_tvalid), .out_tready(out_tready),
           .space(), .occupied());
   endgenerate

endmodule // axis_mux
