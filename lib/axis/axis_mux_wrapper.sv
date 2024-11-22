module axis_mux_wrapper #(
        parameter NUM_INPUTS=8, // Number of AXIS inputs
        parameter BUFFER=0,  // Add small FIFO on egress.
        parameter PRIORITY=0 // Default to Round Robin (0). Fixed Priority(1).
    ) (
        input logic clk,
        input logic rst,
        axis_t.slave in_axis [NUM_INPUTS],
        axis_t.master out_axis
    );


    logic [in_axis[0].WIDTH-1:0] in_tdata  [NUM_INPUTS];
    logic                      in_tvalid [NUM_INPUTS];
    logic                      in_tlast  [NUM_INPUTS];
    logic                      in_tready [NUM_INPUTS];
    logic [out_axis.WIDTH-1:0] out_tdata;
    logic                      out_tvalid;
    logic                      out_tlast;
    logic                      out_tready;

    // Connect all AXIS inputs to MUX
    genvar i;
    generate
        for (i = 0; i < NUM_INPUTS; i++) begin : gen_axis
            always_comb begin
                in_tdata[i]       = in_axis[i].tdata;
                in_tvalid[i]      = in_axis[i].tvalid;
                in_axis[i].tready = in_tready[i];
                in_tlast[i]       = in_axis[i].tlast;
            end
        end
    endgenerate

    // Connect MUX output to AXIS output
    always_comb begin
        out_axis.tdata  = out_tdata;
        out_axis.tvalid = out_tvalid;
        out_axis.tlast  = out_tlast;
        out_tready      = out_axis.tready;
    end

    axis_mux #(
        .NUM_INPUTS(NUM_INPUTS),
        .WIDTH(out_axis.WIDTH),
        .BUFFER(BUFFER),
        .PRIORITY(PRIORITY)
    ) core (
        .clk(clk),
        .rst(rst),

        .in_tdata(in_tdata),
        .in_tvalid(in_tvalid),
        .in_tlast(in_tlast),
        .in_tready(in_tready),

        .out_tdata(out_tdata),
        .out_tvalid(out_tvalid),
        .out_tlast(out_tlast),
        .out_tready(out_tready)
    );
endmodule
