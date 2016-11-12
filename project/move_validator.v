`ifndef move_validator_m
`define move_validator_m

module move_validator (
  input clk,
  input reset,
  input [3:0] piece_to_move,
  input [2:0] piece_x, piece_y,
  input [2:0] move_x, move_y,
  input [3:0] piece_read,

  output reg [5:0] address_validator,
  output reg move_valid,
  output reg validate_complete
  );

  wire  w_pawn_valid, knight_valid, bishop_valid,
        rook_valid, queen_valid, king_valid, b_pawn_valid;
  wire  knight_complete, king_complete, queen_complete,
        bishop_complete, rook_complete, b_pawn_complete,
        w_pawn_complete;
  wire [5:0] address_knight, address_king, address_queen, address_bishop,
              address_rook, address_w_pawn, address_b_pawn;

  // validator modules
  // all validators will need to acess memory
  // so that no friendly piece got miskilled
  validator_knight vkight(clk, knight_complete, reset,
                          piece_x, piece_y, move_x, move_y,
                          piece_read, address_knight[5:3],
                          address_knight[2:0], knight_valid);

  validator_king vking(clk, king_complete, reset,
                      piece_x, piece_y, move_x, move_y,
                      piece_read, address_king[5:3],
                      address_king[2:0], king_valid);

  validator_queen vqueen(clk, queen_complete, reset,
                          piece_x, piece_y, move_x, move_y,
                          piece_read, address_queen[5:3],
                          address_queen[2:0], queen_valid);

  validator_bishop vboshop(clk, bishop_complete, reset,
                          piece_x, piece_y, move_x, move_y,
                          piece_read, address_bishop[5:3],
                          address_bishop[2:0], bishop_valid);

  validator_rook vrook(clk, rook_complete, reset,
                        piece_x, piece_y, move_x, move_y,
                        piece_read, address_rook[5:3],
                        address_rook[2:0], rook_valid);

  validator_w_pawn vwpawn(clk, w_pawn_complete, reset,
                          piece_x, piece_y, move_x, move_y,
                          piece_read, address_w_pawn[5:3],
                          address_w_pawn[2:0], w_pawn_valid);

  validator_b_pawn vbpawn(clk, b_pawn_complete, reset,
                          piece_x, piece_y, move_x, move_y,
                          piece_read, address_b_pawn[5:3],
                          address_b_pawn[2:0], b_pawn_valid);

  // mux the result, memory, complete signal
  always @ ( * ) begin
    if(piece_to_move == 4'd1) begin
      move_valid = w_pawn_valid;
      address_validator = address_w_pawn;
      validate_complete = b_pawn_complete;
    end
    if(piece_to_move == 4'd7) begin
      move_valid = b_pawn_valid;
      address_validator = address_b_pawn;
      validate_complete = w_pawn_complete;
    end
    if(piece_to_move == 4'd2 || piece_to_move == 4'd8) begin
      move_valid = knight_valid;
      address_validator = address_knight;
      validate_complete = knight_complete;
    end
    if(piece_to_move == 4'd3 || piece_to_move == 4'd9) begin
      move_valid = bishop_valid;
      address_validator = address_bishop;
      validate_complete = bishop_complete;
    end
    if(piece_to_move == 4'd4 || piece_to_move == 4'd10) begin
      move_valid = rook_valid;
      address_validator = address_rook;
      validate_complete = rook_complete;
    end
    if(piece_to_move == 4'd5 || piece_to_move == 4'd11) begin
      move_valid = queen_valid;
      address_validator = address_queen;
      validate_complete = queen_complete;
    end
    if(piece_to_move == 4'd6 || piece_to_move == 4'd12) beginn
      move_valid = king_valid;
      address_validator = address_king;
      validate_complete = queen_complete;
    end
  end
endmodule // move_validator
`endif
