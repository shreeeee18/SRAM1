module sram_64k_23 #(
  parameter int DEPTH = 65536,
  parameter int AW    = 16,
  parameter int DW    = 23
)(
  input  logic           clk,
  input  logic           cs_en,     // active high
  input  logic           wr_en,     // 1 = write, 0 = read
  input  logic [AW-1:0]  addr,
  input  logic [DW-1:0]  wr_data,
  output logic [DW-1:0]  rd_data
);

  // Memory array
  logic [DW-1:0] mem [DEPTH];

  // Single-port behavior
  always_ff @(posedge clk) begin
    if (cs_en) begin
      if (wr_en)
        mem[addr] <= wr_data;   // WRITE
      else
        rd_data   <= mem[addr]; // READ (1-cycle latency)
    end
  end

endmodule


