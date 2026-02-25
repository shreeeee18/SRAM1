module sram_apb_cfg #(
  parameter int AW = 16,
  parameter int DW = 23
)(
  input  logic         PCLK,
  input  logic         PRESETn,
  input  logic         PSEL,
  input  logic         PENABLE,
  input  logic         PWRITE,
  input  logic [31:0]  PADDR,
  input  logic [31:0]  PWDATA,
  output logic [31:0]  PRDATA,
  output logic         PREADY,
  output logic         PSLVERR,

  // ===== SRAM INTERFACE (TO TOP) =====
  output logic                sram_cs,
  output logic                sram_wr,
  output logic [AW-1:0]       sram_addr,
  output logic [DW-1:0]       sram_wdata,
  input  logic [DW-1:0]       sram_rdata
);

  logic [DW-1:0] rd_data_q;

  typedef enum logic [1:0] {
    IDLE,
    READ_WAIT,
    READ_CAPTURE,
    READ_RESP
  } rd_state_t;

  rd_state_t rd_state;

  assign PSLVERR = 1'b0;

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      sram_cs    <= 0;
      sram_wr    <= 0;
      sram_addr  <= 0;
      sram_wdata <= 0;
      rd_data_q  <= 0;
      PRDATA     <= 0;
      PREADY     <= 0;
      rd_state   <= IDLE;
    end
    else begin
      // defaults
      sram_cs <= 0;
      sram_wr <= 0;
      PREADY  <= 0;

      case (rd_state)

        // ---------------- IDLE ----------------
        IDLE: begin
          if (PSEL && !PENABLE) begin
            sram_addr <= PADDR[17:2];

            if (PWRITE) begin
              // WRITE
              sram_cs    <= 1;
              sram_wr    <= 1;
              sram_wdata <= PWDATA[DW-1:0];
              PREADY     <= 1;
            end
            else begin
              // READ start
              sram_cs  <= 1;
              rd_state <= READ_WAIT;
            end
          end
        end

        // ---------------- READ_WAIT ----------------
        READ_WAIT: begin
          sram_cs  <= 1;
          rd_state <= READ_CAPTURE;
        end

        // ---------------- READ_CAPTURE ----------------
        READ_CAPTURE: begin
          rd_data_q <= sram_rdata;
          rd_state  <= READ_RESP;
        end

        // ---------------- READ_RESP ----------------
        READ_RESP: begin
          PRDATA   <= {{(32-DW){1'b0}}, rd_data_q};
          PREADY   <= 1;
          rd_state <= IDLE;
        end

      endcase
    end
  end

endmodule