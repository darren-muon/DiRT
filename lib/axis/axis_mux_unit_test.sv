//-------------------------------------------------------------------------------
// File:    axis_mux_unit_test.sv
//
// Author:  Darren Midkiff, Muon Space
// Credit:  This design is based heavily on axis_mux8.sv from Ian Buckley, Ion Concepts LLC
//
// Description:
// Set of unit tests using SVUnit
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`timescale 1ns/1ps

`include "svunit_defines.svh"
`include "axis_mux_wrapper.sv"
`include "drat_protocol.sv"


module axis_mux_unit_test;
   timeunit 1ns; 
   timeprecision 1ps;
   import drat_protocol::*;
   import svunit_pkg::svunit_testcase;

   string name = "axis_mux_ut";
   svunit_testcase svunit_ut;

   logic  clk;
   logic  rst;

   axis_t in[4](.clk(clk));
   axis_t out0(.clk(clk));


   logic [63:0] test_tdata;
   logic 	test_tlast;


   logic    rendeavous;
   int 		timeout;
  

   //
   // Generate clk
   //
   initial begin
      clk <= 1'b1;
      rst <= 1'b0;
      
   end

   always
     #5 clk <= ~clk;

   //===================================
   // This is the UUT that we're 
   // running the Unit Tests on
   //===================================

   axis_mux_wrapper #(
       .NUM_INPUTS(4),
       .BUFFER(0),
       .PRIORITY(0))
   my_axis_mux_0(
      .clk(clk),
      .rst(rst),
      .in_axis(in),
      .out_axis(out0)
   );
  
   //===================================
   // Build
   //===================================
   function void build();
      svunit_ut = new(name);
   endfunction


   //===================================
   // Setup for running the Unit Tests
   //===================================
   task setup();
      svunit_ut.setup();
      /* Place Setup Code Here */
      
      // Reset UUT
      @(posedge clk);
      rst <= 1'b1;
      repeat(10) @(posedge clk);
      rst <= 1'b0;
      idle_all();
      rendeavous <= 1'b0;
      
   endtask


   //===================================
   // Here we deconstruct anything we 
   // need after running the Unit Tests
   //===================================
   task teardown();
      svunit_ut.teardown();
      /* Place Teardown Code Here */
   endtask


   //===================================
   // All tests are defined between the
   // SVUNIT_TESTS_BEGIN/END macros
   //
   // Each individual test must be
   // defined between `SVTEST(_NAME_)
   // `SVTEST_END
   //
   // i.e.
   //   `SVTEST(mytest)
   //     <test code>
   //   `SVTEST_END
   //===================================
   `SVUNIT_TESTS_BEGIN
   
   
   //===================================
   // Test:
   //
   // input0_others_defined
   //
   // Input 0 passes data when selected,
   // all other inputs are defined but ignored.
   //===================================
   `SVTEST(input0_others_defined)
   idle_all();
   fork
      begin : master_thread
	 in[0].write_beat(64'hffff_0000_ffff_0000,1'b0);
	 in[0].write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in[0].write_beat(64'h0000_0000_0000_0000,1'b0);
	 in[0].write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end
      begin : slave_thread
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_0000_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_0000_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 disable watchdog_thread;
      end // block: slave_thread
      begin : watchdog_thread
	 timeout = 10000;	 
	 while(1) begin
	    `FAIL_IF(timeout==0);
	    timeout = timeout - 1;
	    @(negedge clk);	    
	 end	
      end    
   join
   `SVTEST_END

   //===================================
   // Test:
   //
   // input3_followed_by_input0_back_to_back
   //
   // Input 3 the input 0 passes data when selected,
   // all other inputs are defined but ignored.
   //===================================
   `SVTEST(input3_followed_by_input0_back_to_back)
   idle_all();
   fork
      begin : master_thread
	 in[3].write_beat(64'hffff_0000_ffff_0000,1'b0);
	 in[3].write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in[3].write_beat(64'h0000_0000_0000_0000,1'b0);
	 in[3].write_beat(64'hffff_ffff_ffff_ffff,1'b1);
	 in[0].write_beat(64'hffff_0000_ffff_0000,1'b0);
	 in[0].write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in[0].write_beat(64'h0000_0000_0000_0000,1'b0);
	 in[0].write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end
      begin : slave_thread
	 // Packet 1
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_0000_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_0000_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);	 
	 // Packet 2
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_0000_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_0000_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 disable watchdog_thread;
      end // block: slave_thread
      begin : watchdog_thread
	 timeout = 10000;	 
	 while(1) begin
	    `FAIL_IF(timeout==0);
	    timeout = timeout - 1;
	    @(negedge clk);	    
	 end	
      end  
   join
   `SVTEST_END

   //===================================
   // Test:
   //
   // input2_followed_by_input3_then_input0_back_to_back
   //
   // Tests ports 0 and 3 fighting for arbitration after port2 finishes.
   // all other inputs are defined but ignored.
   //===================================
   `SVTEST(input2_followed_by_input3_then_input0_back_to_back)
   idle_all();
   fork
      begin : input3
	 in[2].write_beat(64'hffff_0000_ffff_0003,1'b0);
	 rendeavous <= 1'b1;
	 in[2].write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in[2].write_beat(64'h0000_0000_0000_0000,1'b0);
	 in[2].write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end
      begin : input0
	 while (!rendeavous) @(posedge clk);
	 
	 in[0].write_beat(64'hffff_0000_ffff_0000,1'b0);
	 in[0].write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in[0].write_beat(64'h0000_0000_0000_0000,1'b0);
	 in[0].write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end
      begin : input4
	 while (!rendeavous) @(posedge clk);
	 
	 in[3].write_beat(64'hffff_0000_ffff_0004,1'b0);
	 in[3].write_beat(64'h0000_ffff_0000_ffff,1'b0);
	 in[3].write_beat(64'h0000_0000_0000_0000,1'b0);
	 in[3].write_beat(64'hffff_ffff_ffff_ffff,1'b1);
      end      
      begin : slave_thread
	 // Packet 1 from port 2
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_0000_ffff_0003);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_0000_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);	 
	 // Packet 2 from port 3
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_0000_ffff_0004);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_0000_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 // Packet 3 from port 0
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_0000_ffff_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_ffff_0000_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0000);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'hffff_ffff_ffff_ffff);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 disable watchdog_thread;
      end // block: slave_thread
      begin : watchdog_thread
	 timeout = 10000;	 
	 while(1) begin
	    `FAIL_IF(timeout==0);
	    timeout = timeout - 1;
	    @(negedge clk);	    
	 end	
      end    
   join
   `SVTEST_END
   
   //===================================
   // Test:
   //
   // round_robin
   //
   // 
   // All inputs have pending transactions. 
   // Transactions should proceed in round robin order.
   //===================================

   `SVTEST(round_robin)
   fork
      begin : in0_thread
	in[0].write_beat(64'h0000_0000_0000_0001,1'b0);
	in[0].write_beat(64'h0000_0000_0000_0002,1'b1);
	in[0].write_beat(64'h0000_0000_0000_0003,1'b0);
	in[0].write_beat(64'h0000_0000_0000_0004,1'b1);	 
      end 
      begin : in1_thread
	in[1].write_beat(64'h0000_0000_0001_0001,1'b0);
	in[1].write_beat(64'h0000_0000_0001_0002,1'b1);
	in[1].write_beat(64'h0000_0000_0001_0003,1'b0);
	in[1].write_beat(64'h0000_0000_0001_0004,1'b1);	 	
      end
      begin : in2_thread
       	in[2].write_beat(64'h0000_0000_0002_0001,1'b0);
	in[2].write_beat(64'h0000_0000_0002_0002,1'b1);
	in[2].write_beat(64'h0000_0000_0002_0003,1'b0);
	in[2].write_beat(64'h0000_0000_0002_0004,1'b1);	 
      end
      begin : in3_thread
       	in[3].write_beat(64'h0000_0000_0003_0001,1'b0);
	in[3].write_beat(64'h0000_0000_0003_0002,1'b1);
	in[3].write_beat(64'h0000_0000_0003_0003,1'b0);
	in[3].write_beat(64'h0000_0000_0003_0004,1'b1);	 
      end
      begin : out0_thread
	 //in[0], first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0001);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0002);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in[1], first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0001_0001);
	 `FAIL_UNLESS(test_tlast === 1'b0)
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0001_0002);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in[2], first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0002_0001);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0002_0002);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in[3], first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0003_0001);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0003_0002);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in[0], first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0003);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0000_0004);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in[1], first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0001_0003);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0001_0004);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in[2], first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0002_0003);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0002_0004);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 //in[3], first packet
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0003_0003);
	 `FAIL_UNLESS(test_tlast === 1'b0);
	 out0.read_beat(test_tdata,test_tlast);
	 `FAIL_UNLESS(test_tdata === 64'h0000_0000_0003_0004);
	 `FAIL_UNLESS(test_tlast === 1'b1);
	 disable watchdog_thread;
      end // block: out0_thread
      begin : watchdog_thread
	 timeout = 10000;	 
	 while(1) begin
	    `FAIL_IF(timeout==0);
	    timeout = timeout - 1;
	    @(negedge clk);	    
	 end	
      end    
   join
   `SVTEST_END
     
   //===================================
   `SVUNIT_TESTS_END


     task idle_all();
	in[0].idle_master();
	in[1].idle_master();
	in[2].idle_master();
	in[3].idle_master();
	out0.idle_slave();
     endtask // idle_all
   
endmodule
