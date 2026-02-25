module sram_axi_1024 #(
  parameter int AXI_IDW = 8,
  parameter int AXI_AW  = 44,
  parameter int AXI_DW  = 1024,
  parameter int AXI_SW  = AXI_DW/8
)(
  input  logic clk,
  input  logic rst_n,

  // ============================================================
  // AXI SLAVE INTERFACE
  // ============================================================

  // Write Address
  input  logic [AXI_IDW-1:0] S_AWID,
  input  logic [AXI_AW-1:0]  S_AWADDR,
  input  logic [7:0]         S_AWLEN,
  input  logic [2:0]         S_AWSIZE,
  input  logic [1:0]         S_AWBURST,
  input  logic               S_AWVALID,
  output logic               S_AWREADY,

  // Write Data
  input  logic [AXI_DW-1:0]  S_WDATA,
  input  logic [AXI_SW-1:0]  S_WSTRB,
  input  logic               S_WLAST,
  input  logic               S_WVALID,
  output logic               S_WREADY,

  // Write Response
  output logic [AXI_IDW-1:0] S_BID,
  output logic [1:0]         S_BRESP,
  output logic               S_BVALID,
  input  logic               S_BREADY,

  // Read Address
  input  logic [AXI_IDW-1:0] S_ARID,
  input  logic [AXI_AW-1:0]  S_ARADDR,
  input  logic [7:0]         S_ARLEN,
  input  logic [2:0]         S_ARSIZE,
  input  logic [1:0]         S_ARBURST,
  input  logic               S_ARVALID,
  output logic               S_ARREADY,

  // Read Data
  output logic [AXI_IDW-1:0] S_RID,
  output logic [AXI_DW-1:0]  S_RDATA,
  output logic [1:0]         S_RRESP,
  output logic               S_RLAST,
  output logic               S_RVALID,
  input  logic               S_RREADY,

  // ============================================================
  // AXI MASTER INTERFACE
  // ============================================================

  // Write Address
  output logic [AXI_IDW-1:0] M_AWID,
  output logic [AXI_AW-1:0]  M_AWADDR,
  output logic [7:0]         M_AWLEN,
  output logic [2:0]         M_AWSIZE,
  output logic [1:0]         M_AWBURST,
  output logic               M_AWVALID,
  input  logic               M_AWREADY,

  // Write Data
  output logic [AXI_DW-1:0]  M_WDATA,
  output logic [AXI_SW-1:0]  M_WSTRB,
  output logic               M_WLAST,
  output logic               M_WVALID,
  input  logic               M_WREADY,

  // Write Response
  input  logic [AXI_IDW-1:0] M_BID,
  input  logic [1:0]         M_BRESP,
  input  logic               M_BVALID,
  output logic               M_BREADY,

  // Read Address
  output logic [AXI_IDW-1:0] M_ARID,
  output logic [AXI_AW-1:0]  M_ARADDR,
  output logic [7:0]         M_ARLEN,
  output logic [2:0]         M_ARSIZE,
  output logic [1:0]         M_ARBURST,
  output logic               M_ARVALID,
  input  logic               M_ARREADY,

  // Read Data
  input  logic [AXI_IDW-1:0] M_RID,
  input  logic [AXI_DW-1:0]  M_RDATA,
  input  logic [1:0]         M_RRESP,
  input  logic               M_RLAST,
  input  logic               M_RVALID,
  output logic               M_RREADY,

  // ============================================================
  // SRAM REQUEST INTERFACE (to sram top)
  // ============================================================

  output logic        axi_sram_req,     // request for lookup
  output logic [15:0] axi_sram_addr,    // index into SRAM
  input  logic [22:0] sram_rdata        // returned entry
);

  // ============================================================
  // SRAM entry format
  // [22]    = write enable permission
  // [21]    = read enable permission
  // [20:0]  = Physical Segment Address (PSA)
  // ============================================================

  // ------------------------------------------------------------
  // Internal signals for AW channel
  // ------------------------------------------------------------
  logic aw_busy, aw_wait;
  logic [AXI_AW-1:0] aw_addr_q;
  logic [20:0]       aw_psa_q;
  logic              aw_slverr;
  logic              aw_sram_req;
  logic [15:0]       aw_sram_addr;

  assign S_AWREADY = !aw_busy;

  // AW state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_busy     <= 0;
      aw_wait     <= 0;
      aw_slverr   <= 0;
      aw_sram_req <= 0;
    end else begin
      aw_sram_req <= 0;

      if (S_AWVALID && S_AWREADY) begin
        aw_busy      <= 1;
        aw_wait      <= 1;
        aw_addr_q    <= S_AWADDR;
        aw_sram_req  <= 1;
        aw_sram_addr <= S_AWADDR[43:28];
      end
      else if (aw_wait) begin
        aw_psa_q  <= sram_rdata[20:0];
        aw_slverr <= ~sram_rdata[22];
        aw_wait   <= 0;
      end
      else if (aw_busy && !M_AWVALID) begin
        M_AWADDR  <= {aw_psa_q, aw_addr_q[27:0]};
        M_AWID    <= S_AWID;
        M_AWLEN   <= S_AWLEN;
        M_AWSIZE  <= S_AWSIZE;
        M_AWBURST <= S_AWBURST;
        M_AWVALID <= 1;
      end

      if (M_AWVALID && M_AWREADY) begin
        M_AWVALID <= 0;
        aw_busy   <= 0;
      end
    end
  end

  // ------------------------------------------------------------
  // Internal signals for AR channel
  // ------------------------------------------------------------
  logic ar_busy, ar_wait;
  logic [AXI_AW-1:0] ar_addr_q;
  logic [20:0]       ar_psa_q;
  logic              ar_slverr;
  logic              ar_sram_req;
  logic [15:0]       ar_sram_addr;

  assign S_ARREADY = !ar_busy;

  // AR state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ar_busy     <= 0;
      ar_wait     <= 0;
      ar_slverr   <= 0;
      ar_sram_req <= 0;
    end else begin
      ar_sram_req <= 0;

      if (S_ARVALID && S_ARREADY) begin
        ar_busy      <= 1;
        ar_wait      <= 1;
        ar_addr_q    <= S_ARADDR;
        ar_sram_req  <= 1;
        ar_sram_addr <= S_ARADDR[43:28];
      end
      else if (ar_wait) begin
        ar_psa_q  <= sram_rdata[20:0];
        ar_slverr <= ~sram_rdata[21];
        ar_wait   <= 0;
      end
      else if (ar_busy && !M_ARVALID) begin
        M_ARADDR  <= {ar_psa_q, ar_addr_q[27:0]};
        M_ARID    <= S_ARID;
        M_ARLEN   <= S_ARLEN;
        M_ARSIZE  <= S_ARSIZE;
        M_ARBURST <= S_ARBURST;
        M_ARVALID <= 1;
      end

      if (M_ARVALID && M_ARREADY) begin
        M_ARVALID <= 0;
        ar_busy   <= 0;
      end
    end
  end

  // ------------------------------------------------------------
  // Combine AW / AR SRAM requests (single driver!)
  // ------------------------------------------------------------
  always_comb begin
    if (aw_sram_req) begin
      axi_sram_req  = 1;
      axi_sram_addr = aw_sram_addr;
    end
    else if (ar_sram_req) begin
      axi_sram_req  = 1;
      axi_sram_addr = ar_sram_addr;
    end
    else begin
      axi_sram_req  = 0;
      axi_sram_addr = '0;
    end
  end

  // ------------------------------------------------------------
  // AXI data channel bypass
  // ------------------------------------------------------------
  assign M_WDATA  = S_WDATA;
  assign M_WSTRB  = S_WSTRB;
  assign M_WLAST  = S_WLAST;
  assign M_WVALID = S_WVALID;
  assign S_WREADY = M_WREADY;

  assign S_BID    = M_BID;
  assign S_BRESP  = aw_slverr ? 2'b10 : M_BRESP;
  assign S_BVALID = M_BVALID;
  assign M_BREADY = S_BREADY;

  assign S_RID    = M_RID;
  assign S_RDATA  = M_RDATA;
  assign S_RRESP  = ar_slverr ? 2'b10 : M_RRESP;
  assign S_RLAST  = M_RLAST;
  assign S_RVALID = M_RVALID;
  assign M_RREADY = S_RREADY;

endmodule