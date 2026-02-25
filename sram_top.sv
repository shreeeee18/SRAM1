module sram_top #(
  parameter int AXI_IDW = 8,
  parameter int AXI_AW  = 44,
  parameter int AXI_DW  = 1024,
  parameter int AXI_SW  = AXI_DW/8
)(
  // ==========================================================
  // Clocks & resets
  // ==========================================================
  input  logic clk,        // AXI + SRAM clock
  input  logic rst_n,      // AXI reset (active low)

  input  logic PCLK,       // APB clock
  input  logic PRESETn,    // APB reset (active low)

  // ==========================================================
  // APB CONFIG INTERFACE
  // ==========================================================
  input  logic        PSEL,
  input  logic        PENABLE,
  input  logic        PWRITE,
  input  logic [31:0] PADDR,
  input  logic [31:0] PWDATA,
  output logic [31:0] PRDATA,
  output logic        PREADY,
  output logic        PSLVERR,

  // ==========================================================
  // AXI SLAVE (from Link Controller)
  // ==========================================================

  // AW
  input  logic [AXI_IDW-1:0] S_AWID,
  input  logic [AXI_AW-1:0]  S_AWADDR,
  input  logic [7:0]         S_AWLEN,
  input  logic [2:0]         S_AWSIZE,
  input  logic [1:0]         S_AWBURST,
  input  logic               S_AWVALID,
  output logic               S_AWREADY,

  // W
  input  logic [AXI_DW-1:0]  S_WDATA,
  input  logic [AXI_SW-1:0]  S_WSTRB,
  input  logic               S_WLAST,
  input  logic               S_WVALID,
  output logic               S_WREADY,

  // B
  output logic [AXI_IDW-1:0] S_BID,
  output logic [1:0]         S_BRESP,
  output logic               S_BVALID,
  input  logic               S_BREADY,

  // AR
  input  logic [AXI_IDW-1:0] S_ARID,
  input  logic [AXI_AW-1:0]  S_ARADDR,
  input  logic [7:0]         S_ARLEN,
  input  logic [2:0]         S_ARSIZE,
  input  logic [1:0]         S_ARBURST,
  input  logic               S_ARVALID,
  output logic               S_ARREADY,

  // R
  output logic [AXI_IDW-1:0] S_RID,
  output logic [AXI_DW-1:0]  S_RDATA,
  output logic [1:0]         S_RRESP,
  output logic               S_RLAST,
  output logic               S_RVALID,
  input  logic               S_RREADY,

  // ==========================================================
  // AXI MASTER (to IO-NoC)
  // ==========================================================

  // AW
  output logic [AXI_IDW-1:0] M_AWID,
  output logic [AXI_AW-1:0]  M_AWADDR,
  output logic [7:0]         M_AWLEN,
  output logic [2:0]         M_AWSIZE,
  output logic [1:0]         M_AWBURST,
  output logic               M_AWVALID,
  input  logic               M_AWREADY,

  // W
  output logic [AXI_DW-1:0]  M_WDATA,
  output logic [AXI_SW-1:0]  M_WSTRB,
  output logic               M_WLAST,
  output logic               M_WVALID,
  input  logic               M_WREADY,

  // B
  input  logic [AXI_IDW-1:0] M_BID,
  input  logic [1:0]         M_BRESP,
  input  logic               M_BVALID,
  output logic               M_BREADY,

  // AR
  output logic [AXI_IDW-1:0] M_ARID,
  output logic [AXI_AW-1:0]  M_ARADDR,
  output logic [7:0]         M_ARLEN,
  output logic [2:0]         M_ARSIZE,
  output logic [1:0]         M_ARBURST,
  output logic               M_ARVALID,
  input  logic               M_ARREADY,

  // R
  input  logic [AXI_IDW-1:0] M_RID,
  input  logic [AXI_DW-1:0]  M_RDATA,
  input  logic [1:0]         M_RRESP,
  input  logic               M_RLAST,
  input  logic               M_RVALID,
  output logic               M_RREADY
);

  // ==========================================================
  // SRAM SHARED SIGNALS
  // ==========================================================
  logic        sram_cs;
  logic        sram_wr;
  logic [15:0] sram_addr;
  logic [22:0] sram_wdata;
  logic [22:0] sram_rdata;

  // ==========================================================
  // AXI → SRAM REQUEST 
  // ==========================================================
  logic        axi_sram_req;
  logic [15:0] axi_sram_addr;

  // ==========================================================
  // APB → SRAM REQUEST
  // ==========================================================
  logic        apb_sram_cs;
  logic        apb_sram_wr;
  logic [15:0] apb_sram_addr;
  logic [22:0] apb_sram_wdata;

  // ==========================================================
  // SRAM ARBITRATION
  // ==========================================================
  always_comb begin
    if (axi_sram_req) begin
      sram_cs    = 1'b1;
      sram_wr    = 1'b0;             
      sram_addr  = axi_sram_addr;
      sram_wdata = '0;
    end
    else begin
      sram_cs    = apb_sram_cs;
      sram_wr    = apb_sram_wr;
      sram_addr  = apb_sram_addr;
      sram_wdata = apb_sram_wdata;
    end
  end

  // ==========================================================
  // SRAM INSTANCE
  // ==========================================================
  sram_64k_23 u_sram (
    .clk     (clk),
    .cs_en   (sram_cs),
    .wr_en   (sram_wr),
    .addr    (sram_addr),
    .wr_data (sram_wdata),
    .rd_data (sram_rdata)
  );

  // ==========================================================
  // APB CONFIG BLOCK
  // ==========================================================
  sram_apb_cfg u_apb_cfg (
    .PCLK       (PCLK),
    .PRESETn    (PRESETn),
    .PSEL       (PSEL),
    .PENABLE    (PENABLE),
    .PWRITE     (PWRITE),
    .PADDR      (PADDR),
    .PWDATA     (PWDATA),
    .PRDATA     (PRDATA),
    .PREADY     (PREADY),
    .PSLVERR    (PSLVERR),

    .sram_cs    (apb_sram_cs),
    .sram_wr    (apb_sram_wr),
    .sram_addr  (apb_sram_addr),
    .sram_wdata (apb_sram_wdata),
    .sram_rdata (sram_rdata)
  );

  // ==========================================================
  // AXI ADDRESS MAPPER CORE
  // ==========================================================
  sram_axi_1024 u_axi_core (
    .clk            (clk),
    .rst_n          (rst_n),

    // AXI Slave
    .S_AWID         (S_AWID),
    .S_AWADDR       (S_AWADDR),
    .S_AWLEN        (S_AWLEN),
    .S_AWSIZE       (S_AWSIZE),
    .S_AWBURST      (S_AWBURST),
    .S_AWVALID      (S_AWVALID),
    .S_AWREADY      (S_AWREADY),

    .S_WDATA        (S_WDATA),
    .S_WSTRB        (S_WSTRB),
    .S_WLAST        (S_WLAST),
    .S_WVALID       (S_WVALID),
    .S_WREADY       (S_WREADY),

    .S_BID          (S_BID),
    .S_BRESP        (S_BRESP),
    .S_BVALID       (S_BVALID),
    .S_BREADY       (S_BREADY),

    .S_ARID         (S_ARID),
    .S_ARADDR       (S_ARADDR),
    .S_ARLEN        (S_ARLEN),
    .S_ARSIZE       (S_ARSIZE),
    .S_ARBURST      (S_ARBURST),
    .S_ARVALID      (S_ARVALID),
    .S_ARREADY      (S_ARREADY),

    .S_RID          (S_RID),
    .S_RDATA        (S_RDATA),
    .S_RRESP        (S_RRESP),
    .S_RLAST        (S_RLAST),
    .S_RVALID       (S_RVALID),
    .S_RREADY       (S_RREADY),

    // AXI Master
    .M_AWID         (M_AWID),
    .M_AWADDR       (M_AWADDR),
    .M_AWLEN        (M_AWLEN),
    .M_AWSIZE       (M_AWSIZE),
    .M_AWBURST      (M_AWBURST),
    .M_AWVALID      (M_AWVALID),
    .M_AWREADY      (M_AWREADY),

    .M_WDATA        (M_WDATA),
    .M_WSTRB        (M_WSTRB),
    .M_WLAST        (M_WLAST),
    .M_WVALID       (M_WVALID),
    .M_WREADY       (M_WREADY),

    .M_BID          (M_BID),
    .M_BRESP        (M_BRESP),
    .M_BVALID       (M_BVALID),
    .M_BREADY       (M_BREADY),

    .M_ARID         (M_ARID),
    .M_ARADDR       (M_ARADDR),
    .M_ARLEN        (M_ARLEN),
    .M_ARSIZE       (M_ARSIZE),
    .M_ARBURST      (M_ARBURST),
    .M_ARVALID      (M_ARVALID),
    .M_ARREADY      (M_ARREADY),

    .M_RID          (M_RID),
    .M_RDATA        (M_RDATA),
    .M_RRESP        (M_RRESP),
    .M_RLAST        (M_RLAST),
    .M_RVALID       (M_RVALID),
    .M_RREADY       (M_RREADY),

    // SRAM request interface
    .axi_sram_req   (axi_sram_req),
    .axi_sram_addr  (axi_sram_addr),
    .sram_rdata     (sram_rdata)
  );


endmodule
