import std.stdio, std.exception, std.typecons;

import chess.piece, chess.board;

import gui.chessrt, gui.mainwindow;

void main()
{	
	//auto rt = scoped!ChessRT(640, 480, "Chess 2 Again!");

	try
	{
		run();
	}
	catch (Throwable ex)
	{
		writefln("Exception: %s", ex.toString());
	}
}