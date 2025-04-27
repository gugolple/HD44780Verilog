// Source: https://github.com/njmarencik/debouncer/blob/main/src/debouncer.v
module debouncer #(

	parameter	DIV_CNT	= 18

) (
	input	clk,
	input	btn,

	output	out
);
	
	wire	trig;
	reg	[DIV_CNT:0] clk_div;
	reg	hold;


	initial hold = 1'b0;
	initial clk_div = 0;


	assign	out	= hold;
	assign	trig	= clk_div[DIV_CNT];

	
	always @ (posedge clk) begin
		if (btn) begin
			hold <= 1'b1;
		end else if (trig) begin
			hold <= 1'b0;
			clk_div <= 0;
		end else if (hold) begin
			clk_div <= clk_div + 1'b1;
		end
	end


endmodule