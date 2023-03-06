module axi_stream_insert_header #(
	parameter DATA_WD = 32,
	parameter DATA_BYTE_WD = DATA_WD / 8
) (
	input 							clk,
	input 							rst_n,
 
	// AXI Stream input original data
	input 							valid_in,
	input      [DATA_WD-1 : 0] 		data_in,
	input 	   [DATA_BYTE_WD-1 : 0] keep_in,
	input 							last_in,
	output reg 						ready_in,

	// The header to be inserted to AXI Stream input
	input 							valid_insert,
	input      [DATA_WD-1 : 0]		header_insert,
	input      [DATA_BYTE_WD-1 : 0] keep_insert,
	output reg 						ready_insert,

	// AXI Stream output with header inserted
	output reg 						valid_out,
	output reg [DATA_WD-1 : 0] 		data_out,
	output reg [DATA_BYTE_WD-1 : 0] keep_out,
	output reg 						last_out,
	input 							ready_out
);

	reg   [DATA_WD-1 : 0] 		data_in_t;					//data_in信号打一拍，用于数据拼接输出
	reg   [DATA_BYTE_WD-1 : 0] 	keep_in_t;					//keep_in信号打一拍，用于末尾数据拼接
	reg 						ready_in_t;					//ready_in信号打一拍，用于提取上升沿和下降沿
	
	reg	  [DATA_BYTE_WD-1:0]	keep_in_count;				//对data有效字节个数进行计数
	reg	  [DATA_BYTE_WD-1:0]	keep_insert_count;			//对header有效字节个数进行计数
	reg   [DATA_BYTE_WD-1:0]	keep_insert_lock;			//keep_insert信号寄存，用于确定最后一个输出数据有效位数

	wire 						ready_in_up; 				//取ready_in上升沿用于添加头部数据
	wire						ready_in_down;				//取ready_in下降沿用于确定尾部数据
	wire  [DATA_WD*2-1:0]		header_data;				//拼接header和data
	wire  [DATA_WD*2-1:0]		data_2;						//拼接前后data
	integer 					i,j,k;

	assign ready_in_up   = ~ready_in_t && ready_in;    
	assign ready_in_down = ready_in_t && ~ready_in;	 
	assign header_data 	 = {header_insert, data_in};
	assign data_2 		 = {data_in_t, data_in};

	always @(keep_in_t) begin
		keep_in_count = 0;
		for (i = 0; i < DATA_BYTE_WD; i = i+1) begin
			if(keep_in_t[i])
               	keep_in_count = keep_in_count + 1;
		end
	end

	always @(keep_insert) begin
		keep_insert_count = 0;
		for (j = 0; j < DATA_BYTE_WD; j = j+1) begin
			if(keep_insert[j])
                keep_insert_count = keep_insert_count + 1;
		end
	end


	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			ready_in <= 0;
		end
		else if (last_in) begin
			ready_in <= 0;
		end
		else if (ready_out && valid_insert && valid_in) begin
			ready_in <= 1; 
		end
		else begin
			ready_in <= ready_in;
		end
	end

	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			ready_in_t <= 0;
		end
		else begin
			ready_in_t <= ready_in;
		end
	end

	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			ready_insert <= 0;
		end 
		else if (ready_in) begin
			ready_insert <= 0;
		end
		else if (ready_out && valid_insert && valid_in) begin
			ready_insert <= 1;
		end
		else begin
			ready_insert <= ready_insert;
		end
	end

	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			data_in_t <= 0;
			keep_in_t <= 0;
		end
		else if (ready_in) begin
			data_in_t <= data_in;
			keep_in_t <= keep_in;
		end
		else begin
			data_in_t <= data_in_t;
			keep_in_t <= keep_in_t;
		end
	end


	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			data_out  <= 0;
			keep_out  <= 0;
			last_out  <= 0;
			valid_out <= 0;
			keep_insert_lock <= 0;
		end
		else if (ready_in_up) begin
			data_out <= header_data[DATA_WD*2-1-((DATA_BYTE_WD-keep_insert_count)<<3) -: DATA_WD];
			valid_out <= 1;
			keep_out <= (1<<DATA_BYTE_WD)-1;
			last_out <= 0;
			keep_insert_lock <= keep_insert_count;
		end
		else if (ready_in) begin
			data_out <= data_2[DATA_WD*2-1-((DATA_BYTE_WD-keep_insert_lock)<<3) -: DATA_WD];
			valid_out <= 1;
			keep_out <= (1<<DATA_BYTE_WD)-1;
			last_out <= 0;
			keep_insert_lock <= keep_insert_lock;
		end
		else if (ready_in_down) begin
			data_out <= data_2[DATA_WD*2-1-((DATA_BYTE_WD-keep_insert_lock)<<3) -: DATA_WD];
			valid_out <= 1;
			for(k = 0;k < DATA_BYTE_WD;k=k+1)
				if(k < (DATA_BYTE_WD+DATA_BYTE_WD-keep_insert_lock-keep_in_count))
					keep_out[k] <= 0;
				else
					keep_out[k] <= 1; 
			last_out <= 1;
			keep_insert_lock <= keep_insert_lock;
		end
		else begin
			data_out <= data_out;
			keep_out <= keep_out;
			keep_insert_lock <= keep_insert_lock;
			last_out <= 0;
			valid_out <= 0;
		end
	end
endmodule