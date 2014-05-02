--
-- Author: Ace
-- Date: 2014-03-29 00:22:37
--
local Language = {}

Language.info = {
	start 	= " Welcome to 'Crystal Twos' ",
	guide 	= " Sliding on the board to move ",
	clicked = "Moving is expected ...",
	pressed = "There's a secret I don't want to tell you",
	moved 	= {
		" Go ahead! ",
		" The more crystal, the more exciting ",
		" Let's merge more bigger numbers ",
		" Crystal, coming soon coming more! ",
		" Keep the biggest number in corner ",
		" If ystday once more, or game can undo ",
		" Regret doing, or regret to do? ",
		" Playing is easy, developing is difficult ",
		" Touch Score board to switch Mode",
	},
	merged = {
		" Good job! ",
		" Well done! ",
		"New crystal always come from other side",
		" Crystal is fascinating, defacing is crime! ",
		" It's a wonderful game, do you think so? ",
		" 2048 is a magical crystal, catch it! ",
		" I think nobody can get to 50000 point ",
		" A bigger number will come on later ",
		" Don't put all your crystals in one box ",
	},

	lost 		= " Out of moves, try again? ",
	nomoved 	= " You cannot move to this direction! ",
	win1	 	= " You have got a new crystal! ",
	win2	 	= " You are crazy, I don't believe my eyes ",
	win3	 	= " Eeverybody, come here to see the God! ",
	undoHint	= " Undo is better than refuse to repent ",
	undoed 		= " My pleasure as long as you like it ",
	notUndo		= " Sorry, there is not any more undo ",
	restartHint = "Press the button for 1s to restart game",
	exitHint	= " Tap again to exit game",
	saved 		= " The Game State Is Saved ",
	restored 	= " Continue or tap [New] for new game ",
}

Language.title = {
	newgame		= " New ",
	exit 		= " Exit ",
	text 		= "Merge the same crystals, Black-2\nis can only joined with White-2 ..",
	-- text1 		= "Merge the same crystals, Black-2 can only join with White-2",
	currScore 	= "Score",
	bestScore 	= "BestSc.",
	bestCell 	= "BestCell",
	nextCell 	= "Next",
}

return Language
