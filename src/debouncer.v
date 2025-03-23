module debouncer
#(
  // Short config sets the module to work in 4 bit wide
  parameter COUNT = 6
)
(
  input clk,
  input in,
  output floating,
  output flag
);
reg lastin;
wire rst;
wire cnted;
counter #(
    .COUNT(COUNT),
    .RESET(0)
  )cnt (
    .clk(clk),
    .rst(rst),
    .flag(cnted)
  );

assign floating = !cnted;
assign rst = in ^ lastin;
assign flag = lastin;

always @(posedge clk) begin
  lastin = in;
end

endmodule