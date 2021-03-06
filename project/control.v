`ifndef control_m
`define control_m
`include "configrable_clock.v"
`include "piece_validator.v"
`include "move_validator.v"
module control (
  input clk,
  input reset,
  input up, down, left, right,
  input select, deselect,
  input [3:0] piece_read,
  input initialize_complete, // feed back signal from datapath
  input move_complete, // feed back signal from datapath
  input board_render_complete,
  input start_render_board_received, // feed back from view
  input erase_complete, // feed back from view (erase the box)
  // breakpoints used for debugging
  input break_point1,
  input break_point2,
  input break_point3,

  output reg current_player,
  output reg winning_msg, // winning condition satisfied?
  output reg [2:0] origin_x, origin_y, // left down corner (0,0)
  output reg [2:0] destination_x, destination_y, // position piece is moving to
  output reg [3:0] piece_to_move,
  output reg [2:0] box_x, box_y, // select box position
  // control signals
  // 00: control
  // 01: validator
  // 10: datapath
  // 11: view
  output reg [1:0] memory_manage, // memory control signal
  output [5:0] address_validator,
  output reg start_render_board,
  output reg re_render_box_position,
  output reg move_piece, // start update memory in datapath
  output reset_clock, // reset the clock for box blinking
  output reg initialize_board, // start initialze memory in datapath
  output [8:0] current_state_display // for debugging
  );

  // FSM
  reg winning;
  wire move_valid;
  wire piece_valid;
  reg select_box_can_move;
  reg read_destination;
  reg start_validation;
  wire validate_complete;

  reg [15:0] current_state, next_state;

  localparam  S_PRE_INIT = 16'd16384,
              S_INIT = 16'd0,
              S_INIT_WAIT = 16'd1,
              S_UPDATE_MONITOR = 16'd2,
              S_UPDATE_MONITOR_WAIT = 16'd4,
              S_MOVE_BOX_1 = 16'd8,
              S_SELECT_PIECE = 16'd16,
              S_VALIDATE_PIECE = 16'd32,
              S_MOVE_BOX_2 = 16'd64,
              S_SELECT_DESTINATION = 16'd128,
              S_SELECT_DESTINATION_WAIT = 16'd256,
              S_VALIDATE_DESTINATION = 16'd512,
              S_CHECK_WINNING = 16'd1024,
              S_UPDATE_MEMORY = 16'd2048,
              S_UPDATE_MEMORY_WAIT = 16'd4096,
              S_GAME_OVER = 16'd8192;


  // validate piece
  // check legal
  piece_validator pv(current_player, piece_read, piece_valid);

  assign reset_clock = reset || (current_state == S_PRE_INIT);
  // debugging
  assign current_state_display = current_state[8:0];

// state table
always @ ( * ) begin
    case (current_state)
      // show the entrance background
      S_PRE_INIT: next_state = (up || down || right || left) ? S_INIT : S_PRE_INIT;
      // initialize memory
      S_INIT: next_state = S_INIT_WAIT;
      S_INIT_WAIT: next_state = initialize_complete ? S_UPDATE_MONITOR: S_INIT_WAIT;
      // update monitor based on memory status
      // until the signal is received, continuously sending the start signal
      S_UPDATE_MONITOR: next_state = start_render_board_received ? S_UPDATE_MONITOR_WAIT : S_UPDATE_MONITOR;
      S_UPDATE_MONITOR_WAIT: next_state = board_render_complete ? S_MOVE_BOX_1 : S_UPDATE_MONITOR_WAIT;
      // moving select box
      S_MOVE_BOX_1: begin
        if(select)
          next_state = S_SELECT_PIECE;
        else
          next_state = S_MOVE_BOX_1;
      end
      // get current selected piece to piece_to_move
      // player need to turn off select(SW[0])
      S_SELECT_PIECE: begin
		  if(!break_point1)
		    next_state = select ? S_SELECT_PIECE : S_VALIDATE_PIECE;
		  else
		    next_state = S_SELECT_PIECE;
		end
      // find whether the piece is valid(valid => select destination: invalid => select piece_to_move)
      S_VALIDATE_PIECE: next_state = piece_valid ? S_MOVE_BOX_2 : S_MOVE_BOX_1;
      // moving select box
      S_MOVE_BOX_2: begin
      // possibly problematic part
         if(~deselect) begin
        //   // if(select && erase_complete)
           if(select)
             next_state = S_SELECT_DESTINATION;
           else
             next_state = S_MOVE_BOX_2;
         end
         else begin
           // jump back if deselect piece
           if(!select) next_state = S_MOVE_BOX_1;
           else next_state = S_MOVE_BOX_2;
         end
//        next_state = select ? S_SELECT_DESTINATION : S_MOVE_BOX_2;
      end
      // start validate destination && get current position to destination
      // player need to turn off select(SW[0])
      S_SELECT_DESTINATION: begin
		  if(!break_point2)
		    next_state = select ? S_SELECT_DESTINATION :S_SELECT_DESTINATION_WAIT;
		  else
		    next_state = S_SELECT_DESTINATION;
		end
      // wait validator to complete
      S_SELECT_DESTINATION_WAIT: next_state = validate_complete ? S_VALIDATE_DESTINATION : S_SELECT_DESTINATION_WAIT;
      // validate the destination choice
      S_VALIDATE_DESTINATION: next_state = move_valid ? S_CHECK_WINNING : S_MOVE_BOX_2;
      S_CHECK_WINNING: next_state = winning ? S_GAME_OVER : S_UPDATE_MEMORY;
      S_UPDATE_MEMORY: next_state = S_UPDATE_MEMORY_WAIT;
      S_UPDATE_MEMORY_WAIT: next_state = move_complete ? S_UPDATE_MONITOR : S_UPDATE_MEMORY_WAIT;
      S_GAME_OVER: next_state = reset ? S_INIT : S_GAME_OVER;
      default: next_state = S_PRE_INIT;
    endcase
end

// setting signals
reg ld_origin, ld_destination;
always @ ( * ) begin
  // by default set all signals to 0
  select_box_can_move = 1'b0;
  initialize_board = 1'b0;
  move_piece = 1'b0;
  start_validation = 1'b0;
  start_render_board = 1'b0;
  winning_msg = 1'b0;
  // default grant memory access to control
  memory_manage = 2'b00;
  ld_origin = 1'b0;
  ld_destination = 1'b0;

  case(current_state)
    S_INIT: initialize_board = 1'b1;
    S_INIT_WAIT: memory_manage = 2'b10; // grant memory access to datapath
    S_UPDATE_MONITOR: start_render_board = 1'b1;
    S_UPDATE_MONITOR_WAIT: memory_manage = 2'b11; // grant memory access to view
    S_MOVE_BOX_1: select_box_can_move = 1'b1;
	 S_SELECT_PIECE: ld_origin = 1'b1;
    S_MOVE_BOX_2: select_box_can_move = 1'b1;
    S_SELECT_DESTINATION: begin
	   start_validation = 1'b1;
		ld_destination = 1'b1;
	 end
    S_SELECT_DESTINATION_WAIT: memory_manage = 2'b01; // grant memory access to validator module
    S_UPDATE_MEMORY: move_piece = 1'b1;
    S_UPDATE_MEMORY_WAIT: memory_manage = 2'b10; // grant datapath to access memory
    S_GAME_OVER: winning_msg = 1'b1;
  endcase
end

// flip player
always @ ( posedge clk ) begin
  case (current_state)
    S_INIT: current_player <= 1'b0;
    S_CHECK_WINNING: current_player <= ~current_player;
    default: current_player <= current_player;
  endcase
end

// select piece
always @ ( posedge clk ) begin
  if(ld_origin) begin
    origin_x <= box_x;
    origin_y <= box_y;
    piece_to_move <= piece_read; // info to datapath
  end
  if(current_state == S_INIT) begin
    origin_x <= 3'b0;
    origin_y <= 3'b0;
	 piece_to_move <= 4'd0;
  end
    
//  case (current_state)
//    S_SELECT_PIECE: begin
//      origin_x <= box_x;
//      origin_y <= box_y;
//      piece_to_move <= piece_read; // info to datapath
//    end
//    S_INIT: begin
//      origin_x <= 3'b0;
//      origin_y <= 3'b0;
//    end
//    default: begin
//      origin_x <= origin_x;
//      origin_y <= origin_y;
//    end
//  endcase
//  $display("[SelectPiece] %d x:%d, y:%d", piece_to_move, origin_x, origin_y);
end

// select destination
always @ ( posedge clk ) begin
  if(ld_destination) begin
    destination_x <= box_x;
    destination_y <= box_y;
  end
  if(current_state == S_INIT) begin
    destination_x <= 3'b0;
    destination_y <= 3'b0;
  end
  
//  case (current_state)
//    S_SELECT_DESTINATION: begin
//      destination_x <= box_x;
//      destination_y <= box_y;
//    end
//    S_INIT: begin
//      destination_x <= 3'b0;
//      destination_y <= 3'b0;
//    end
//    default: begin
//      destination_x <= destination_x;
//      destination_y <= destination_y;
//    end
//  endcase
//  $display("[SelectDestination] %d x:%d, y:%d", piece_read, destination_x, destination_y);
end

// check winning
always @ ( posedge clk ) begin
  if(ld_destination)
    winning <= ((piece_read == 4'd6) || (piece_read == 4'd12));
//	 $display("piece read: %d", piece_read);
  if(current_state == S_INIT)
    winning <= 1'b0;
end

wire current_player_mv;
assign current_player_mv = current_player;
// validate move
move_validator mv(clk, reset, start_validation, current_player_mv, piece_to_move, origin_x, origin_y,
                 destination_x, destination_y, piece_read, address_validator,
                 move_valid, validate_complete);
// mocking move_validator
//  reg [2:0] move_counter;
//  assign validate_complete = move_counter == 3'b111;
//  always @ ( posedge clk ) begin
//    if(reset_clock) move_counter <= 3'b0;
//    else begin
//      if(memory_manage == 2'b1) begin
//        $display("[Mocking Validator]");
//        move_counter <= move_counter + 1;
//      end
//    end
//    move_valid <= 1'b1;
//  end

// setting state
always @ ( posedge clk ) begin
  if(reset)
    current_state <= S_INIT;
  else
    current_state <= next_state;
end

wire frame_clk;
// 2Hz clock for not so fast select-box moving
configrable_clock #(26'd25000000) c0(clk, reset_clock, frame_clk);
// high frequency clk for testing
// configrable_clock #(26'd1) c0(clk, reset_clock, frame_clk);
// select box
//assign re_render_box_position = (current_state == S_MOVE_BOX_1 || current_state == S_MOVE_BOX_2) &&
//                                ((up || down || right || left));

always @(posedge clk) begin
  if(current_state == S_INIT)
    re_render_box_position <= 1'b0;
  if(select_box_can_move) begin
    if(up || down || right || left) begin
	   re_render_box_position <= 1'b1;
	 end
	 if(erase_complete) begin
	   re_render_box_position <= 1'b0;
	 end
  end
end

//reg [2:0] temp_x, temp_y; // storing x, y before erase the current box position
always @ ( posedge clk ) begin
  if(current_state == S_INIT) begin
    box_x <= 3'b0;
    box_y <= 3'b0;
//	 temp_x <= 3'b0;
//	 temp_y <= 3'b0;
  end
    if(select_box_can_move && frame_clk) begin
    if(up) box_y <= box_y + 1;
    if(down) box_y <= box_y - 1;
    if(right) box_x <= box_x + 1;
    if(left) box_x <= box_x - 1;
  end
//  if(select_box_can_move && frame_clk) begin
//    if(up) temp_y <= box_y + 1;
//    if(down) temp_y <= box_y - 1;
//    if(right) temp_x <= box_x + 1;
//    if(left) temp_x <= box_x - 1;
//  end
//  if(erase_complete) begin
//    box_x <= temp_x;
//	 box_y <= temp_y;
//  end
end

  // log block
//   wire write_log;
//   configrable_clock #(26'd10) clog(clk, reset_clock, write_log);
//   always @(posedge clk) begin
// 	if(write_log) begin
// 	   $display("-----------------Control----------------------");
// 	   $display("[Controller] Current state is state[%d]", next_state);
//		if(current_state == S_MOVE_BOX_1)
//	     $display("reading %d from %d, %d", piece_read, box_x, box_y);
// 	end
//	if(current_state > 6'd8)
//     $display("Current state is state %d", current_state);
//	if(current_state == S_CHECK_WINNING)
//	  $display("Winning:%b", winning);
//	if(current_state == S_VALIDATE_DESTINATION)
//	  $display("%d From %d, %d to %d, %d", piece_to_move, origin_x, origin_y, destination_x, destination_y);

//	if(current_state == 6'd8)
//	  $display("select: %b", select);
// 	case(current_state)
//     S_INIT: $display("Init");
//     S_MOVE_BOX_1: begin
//       $display("[SelectBox1] Current position [x:%d][y:%d]", box_x, box_y);
//     end
//     S_MOVE_BOX_2: begin
//       $display("[SelectBox2] Current position [x:%d][y:%d]", box_x, box_y);
//     end
// 	 S_SELECT_PIECE: begin
// 		$display("selecting piece");
// 	 end
//   endcase
//   end
endmodule // control
`endif
