module top(
    output sw_s_in,
    output sw_s_pos10,
    output sw_s_neg10,
    input comp_vcomp,
    input comp_vzero,
    output sw_discharge,
    
    input uart_rx,
    output uart_tx,
    
    input reset_n,
    input clk
);
// not used
reg sw_discharge_r;
assign sw_discharge = sw_discharge_r;

reg sw_s_in_r;
assign sw_s_in = ~sw_s_in_r;
reg sw_s_pos10_r;
assign sw_s_pos10 = ~sw_s_pos10_r;
reg sw_s_neg10_r;
assign sw_s_neg10 = ~sw_s_neg10_r;

reg [31:0] runup_total_cycle;
reg [31:0] runup_pos_cycle;
reg [31:0] runup_neg_cycle;

reg [1:0] edge_vzero;

// main fsm
localparam STATUS_RESET                 = 8'b00000001;
localparam STATUS_IDLE                  = 8'b00000010;
localparam STATUS_ZEROLIZE              = 8'b00000100;
localparam STATUS_RUNUP                 = 8'b00001000;
localparam STATUS_RUNDOWN               = 8'b00100000;
localparam STATUS_TRANSMIT              = 8'b01000000;
localparam STATUS_FINISH                = 8'b10000000;

reg [7:0] status_current;
reg [7:0] status_next;


always @(posedge clk) begin
    if (!reset_n) begin
        status_current <= STATUS_RESET;
    end else begin
        status_current <= status_next;
    end
end

always @(*) begin
    case (status_current)
        STATUS_RESET: begin
            status_next = STATUS_IDLE;
        end
        STATUS_IDLE: begin
            status_next = STATUS_ZEROLIZE;
        end
        STATUS_ZEROLIZE: begin
            if (edge_vzero == 2'b10 || edge_vzero == 2'b01) begin
                status_next = STATUS_RUNUP;
            end else begin
                status_next = STATUS_ZEROLIZE;
            end
        end
        STATUS_RUNUP: begin
            if (runup_total_cycle >= 10000000 - 1) begin
                status_next = STATUS_RUNDOWN;
            end else begin
                status_next = STATUS_RUNUP;
            end
        end
        STATUS_RUNDOWN: begin
            if (edge_vzero == 2'b10 || edge_vzero == 2'b01) begin
                status_next = STATUS_TRANSMIT;
            end else begin
                status_next = STATUS_RUNDOWN;
            end
        end
        STATUS_TRANSMIT: begin
            status_next = STATUS_FINISH;
        end
        STATUS_FINISH: begin
            status_next = STATUS_FINISH;
        end
    endcase
end

always @(posedge clk) begin
    case (status_current)
        STATUS_RESET:
        STATUS_IDLE: begin
            runup_total_cycle       <= 32'b0;
            runup_pos_cycle         <= 32'b0;
            runup_neg_cycle         <= 32'b0;
            
            sw_s_in_r               <= 1'b0;
            sw_s_pos10_r            <= 1'b0;
            sw_s_neg10_r            <= 1'b0;
            
            edge_vzero              <= {comp_vzero, comp_vzero};
        end
        STATUS_ZEROLIZE: begin
            if(comp_vzero == 0) begin
                sw_s_pos10_r    <= 1'b1;
                sw_s_neg10_r    <= 1'b0;
            end else begin
                sw_s_pos10_r    <= 1'b0;
                sw_s_neg10_r    <= 1'b1;
            end
            edge_vzero <= {edge_vzero[0], comp_vzero};
        end
        STATUS_RUNUP: begin
            sw_s_in_r       <= 1'b1;
            if(comp_vzero == 0) begin
                sw_s_pos10_r    <= 1'b1;
                sw_s_neg10_r    <= 1'b0;
                runup_pos_cycle <= runup_pos_cycle + 1;
            end else begin
                sw_s_pos10_r    <= 1'b0;
                sw_s_neg10_r    <= 1'b1;
                runup_neg_cycle <= runup_neg_cycle + 1;
            end
            runup_total_cycle   <= runup_total_cycle + 1;
            edge_vzero    <= {edge_vzero[0], comp_vzero};
        end
        STATUS_RUNDOWN: begin
            sw_s_in_r       <= 1'b0;
            if(comp_vzero == 0) begin
                sw_s_pos10_r    <= 1'b1;
                sw_s_neg10_r    <= 1'b0;
                runup_pos_cycle <= runup_pos_cycle + 1;
            end else begin
                sw_s_pos10_r    <= 1'b0;
                sw_s_neg10_r    <= 1'b1;
                runup_neg_cycle <= runup_neg_cycle + 1;
            end
            runup_total_cycle   <= runup_total_cycle + 1;
            edge_vzero <= {edge_vzero[0], comp_vzero};
        end
    endcase
end

thcattus_uart_tx uart_tx_inst(
    .axis_aclk(clk),
    .axis_arestn(reset_n),
    
    .axis_tvalid(status_current == STATUS_TRANSMIT),
    .axis_tready(),
    
    .axis_tdata({runup_pos_cycle,runup_neg_cycle,runup_total_cycle}),
    
    .uart_tx(uart_tx)
);

endmodule