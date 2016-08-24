module gui.opengl_demo;

import gui.guibase;
import rt.color;
static import gfm.math.vector;

alias Vector = gfm.math.vector.Vector!(float, 2);

import std.algorithm : min, max, clamp;
import std.math : PI, sqrt, sin, cos;
import std.typecons : Rebindable;

class OpenGLDemo : GuiBase!Color
{	
	Simulator simulator;

	this(uint width, uint height, string windowTitle)
	{
		import std.variant : Variant;
		super(Variant(super.InitSettings(width, height, windowTitle)));

		simulator = new Simulator;
		simulator.populate();

		// Create and attach the custom AI
		CellAI ai = new DefaultAI();
		ai.prepare();
		
		simulator.addPlayerCell(ai, Color(0.0f, 1.0f, 1.0f));
	}

	int getCircleSegmentCount(float radius)
	{
		enum float MAX_LINE_LENGTH = 0.01f;
		return cast(int)clamp(PI * radius / MAX_LINE_LENGTH, 8.0f, 128.0f);
	}
	
	void drawCircle(Vector center, float radius, bool fillCircle)
	{
		import derelict.opengl3.constants : GL_TRIANGLE_FAN, GL_LINE_LOOP;
		import derelict.opengl3.gl : glBegin, glVertex2f, glEnd;

		int circleSegmentCount = getCircleSegmentCount(radius);
		
		float stepAngleRadian = PI / circleSegmentCount;
		float stepCos = cos(stepAngleRadian);
		float stepSin = sin(stepAngleRadian);
		
		float x = radius;
		float y = 0.0f;
		
		glBegin(fillCircle ? GL_TRIANGLE_FAN : GL_LINE_LOOP);
		while (0 < circleSegmentCount) {
			glVertex2f(center.x + x, center.y + y);
			
			float rotatedX = stepCos * x - stepSin * y;
			float rotatedY = stepSin * x + stepCos * y;
			x = rotatedX;
			y = rotatedY;
			
			--circleSegmentCount;
		}
		glEnd();
	}
	
	override void render()
	{
		import derelict.opengl3.gl;

		// Clear buffer
		glClearColor(1.0f, 0.5f, 0.3f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT);

		// Draw arena
		glColor3f(1.0f, 1.0f, 1.0f);
		glLineWidth(2.0f);
		drawCircle(simulator.settings.arenaCenter, simulator.settings.arenaRadius, false);
		
		// Get simulator info
		const PlayerCellInfo[] playerCellInfo = simulator.getPlayerCellInfos();
		auto playerCount = playerCellInfo.length;

		const Cell[] cells = simulator.getCells();
		auto cellCount = cells.length;
		
		// Draw players	
		for (int playerIndex = 0; playerIndex < playerCount; ++playerIndex) {
			const PlayerCellInfo* playerInfo = &playerCellInfo[playerIndex];

			with (playerInfo.color)
				glColor3f(r, g, b);
			
			const Cell* playerCell = &cells[playerInfo.cellIndex];
			drawCircle(playerCell.position, playerCell.radius, true);
		}
		
		// Draw NPC cells
		for (auto cellIndex = playerCount; cellIndex < cellCount; ++cellIndex) {
			const Cell* cell = &cells[cellIndex];
			
			if (playerCount == 1) {
				const Cell* playerOne = &cells[0];
				if (cell.radius < playerOne.radius) {
					glColor3f(0.0f, 1.0f, 0.0f);
				} else {
					glColor3f(1.0f, 0.0f, 0.0f);
				}
			} else {
				glColor3f(0.5f, 0.5f, 0.5f);
			}
			
			drawCircle(cell.position, cell.radius, true);
		}
		
//		if (g_player && g_prey && g_predator)
//		{
//			drawLine(g_player, g_prey);
//			drawLine(g_player, g_predator);
//		}
//		else if (g_player && g_predator)
//			drawLine(g_player, g_predator);
//		else if (g_player && g_prey)
//			drawLine(g_player, g_prey);
		
		// Swap buffers
		gui.window.swapBuffers();
	}
	
	override void update()
	{
		super.update();

		simulator.tick();
	}
	
	override bool handleInput()
	{
		import derelict.sdl2.types;

		auto kbd = super.gui.sdl2.keyboard;

		if (kbd.isPressed(SDLK_SPACE))
			simulator.toggleSimulationPause();

		if (kbd.isPressed(SDLK_RIGHT) && 
			simulator.getState() == Simulator.State.PAUSED)
			simulator.tick();
		
		return super.handleInput;
	}
}

struct PlayerCellInfo
{
	size_t cellIndex = -1;
	Rebindable!(const CellAI) ai;
	Color color;
}

struct Cell
{
	float radius = 0.0;
	Vector position;
	Vector velocity;
	
	bool isDead() const { return radius < 0.000001; }
	
	float getArea() const { return PI * radius * radius; }

	void setArea(float newArea)
	{
		if (newArea < 0) newArea = 0.0;
		radius = sqrt((1 / PI) * newArea);
	}
}

interface CellAI
{	
	void prepare();
	
	Vector calculateAcceleration(const Cell[] cells) const;
}

class DefaultAI : CellAI
{
	void prepare() { }

	Vector calculateAcceleration(const Cell[] cells) const
	{
		return Vector(0.2, 0.5);
	}
}

class SimSettings
{
	// Test parameters. Frequently changed. Overloaded by command line.
	int levelSeed = 0;
	int cellCount = 256;
	
	// Simulation parameters. Usually don't change.
	float cellMinimumRadius = 0.005;
	float cellMaximumRadius = 0.02;
	float cellMaximumVelocity = 0.3;
	float playerCellInitialRadius = 0.01;
	int exitOnSimulationFinished = 1;
	
	// System parameters. Almost never change.
	int playerCellCount = 1;
	Vector arenaCenter;
	float arenaRadius = 1;
	float tickLength = 0.005;
	int displayResolution = 640;

	string settingsFilePath = "./settings.txt";
	
	void load()
	{
		import core.stdc.stdio;
		import std.string : toStringz;

		FILE* settingsFile = fopen(settingsFilePath.toStringz, "r");

		if (!settingsFile)
			return;

		fscanf(settingsFile, "%*s %d", &levelSeed);
		fscanf(settingsFile, "%*s %d", &cellCount);
		
		fscanf(settingsFile, "%*s %f", &cellMinimumRadius);
		fscanf(settingsFile, "%*s %f", &cellMaximumRadius);
		fscanf(settingsFile, "%*s %f", &cellMaximumVelocity);
		fscanf(settingsFile, "%*s %f", &playerCellInitialRadius);
		fscanf(settingsFile, "%*s %d", &exitOnSimulationFinished);
		
		fscanf(settingsFile, "%*s %d", &playerCellCount);
		fscanf(settingsFile, "%*s %f %f", &arenaCenter.x, &arenaCenter.y);
		fscanf(settingsFile, "%*s %f", &arenaRadius);
		fscanf(settingsFile, "%*s %f", &tickLength);
		fscanf(settingsFile, "%*s %d", &displayResolution);
		
		playerCellCount = (playerCellCount < cellCount) ? playerCellCount : cellCount;
		
		fclose(settingsFile);
	}
}

extern(C) void srand(uint);

float getFloatSample(const float minValue = -1.0f, const float maxValue = 1.0f) {
	import std.random : uniform;
	return uniform(minValue, maxValue);
}

Vector getRandomDirection() {
	float theta = getFloatSample(0.0f, PI);
	return Vector(cos(theta), sin(theta));
}

Vector getDiskSample(float diskRadius) {
	float radius = getFloatSample(0.0f, diskRadius);
	return sqrt(radius) * getRandomDirection();
}

class Simulator
{
	enum State
	{
		NOT_READY,
		READY,
		PAUSED,
		FINISHED
	}

	private
	{
		SimSettings settings = new SimSettings;

		State state;
		
		Cell* cells;
		Cell* playerViewCells;
		int liveCellCount;
		
		PlayerCellInfo* playerCellInfo;
		int livePlayerCellCount;
	}
	
	
	State getState() const { return this.state; }

	const(Cell)[] getCells() const
	{
		return this.cells[0 .. liveCellCount];
	}

	const(PlayerCellInfo)[] getPlayerCellInfos() const
	{
		return this.playerCellInfo[0 .. livePlayerCellCount];
	}
	
	void toggleSimulationPause()
	{
		if (state == State.PAUSED)
			state = State.READY;
		else if (state == State.READY)
			state = State.PAUSED;
	}
	
	void populate()
	{


		// Seed the random generator
		srand(settings.levelSeed);
		
		// Allocate cells
		if (0 < settings.cellCount) {
			cells = new Cell[settings.cellCount].ptr;
			playerViewCells = new Cell[settings.cellCount].ptr;
			liveCellCount = settings.cellCount;
		}
		
		// Allocate player cell info
		if (0 < settings.playerCellCount) {
			playerCellInfo = new PlayerCellInfo[settings.playerCellCount].ptr;
			livePlayerCellCount = 0;
		}
		
		// Place players
		if (settings.playerCellCount == 1) {
			// Single player
			cells[0].radius = settings.playerCellInitialRadius;
			cells[0].position = settings.arenaCenter;
		} else {
			// Multiplayer
			int placedPlayerCells = 0;
			while (placedPlayerCells < settings.playerCellCount) {
				// Place new player
				Cell* newCell = &cells[placedPlayerCells];
				newCell.radius = settings.playerCellInitialRadius;
				newCell.position = settings.arenaCenter + getDiskSample(settings.arenaRadius - settings.playerCellInitialRadius);
				
				// Check if the new player is OK with the other players
				bool isOkWithOtherCells = true;
				for (int placedPlayerIndex = 0; placedPlayerIndex < placedPlayerCells; ++ placedPlayerIndex) {
					const Cell* placedPlayer = &cells[placedPlayerIndex];
					if (areCellsColliding(*newCell, *placedPlayer)) {
						isOkWithOtherCells = false;
						break;
					}
				}
				
				// Move to the next cell to place
				if (isOkWithOtherCells) {
					++placedPlayerCells;
				}
			}
		}
		
		// Place cells
		int placedCells = settings.playerCellCount;
		while (placedCells < liveCellCount) {
			// Place new cell
			Cell* newCell = &cells[placedCells];
			newCell.radius = getFloatSample(settings.cellMinimumRadius, settings.cellMaximumRadius);
			newCell.position = settings.arenaCenter + getDiskSample(settings.arenaRadius - newCell.radius);
			newCell.velocity = settings.cellMaximumVelocity * getRandomDirection();
			
			// Check if the new cell is OK with the other players and cells
			bool isOkWithOtherCells = true;
			for (int placedCellIndex = 0; placedCellIndex < placedCells; ++ placedCellIndex) {
				const Cell* placedCell = &cells[placedCellIndex];
				if (areCellsColliding(*newCell, *placedCell)) {
					isOkWithOtherCells = false;
					break;
				}
			}
			
			// Move to the next cell to place
			if (isOkWithOtherCells) {
				++placedCells;
			}
		}
		
		state = State.READY;
	}
	
	void addPlayerCell(const CellAI cellAI, const Color color)
	{
		if (state != State.READY || livePlayerCellCount < settings.playerCellCount)
			return;

		playerCellInfo[livePlayerCellCount].cellIndex = livePlayerCellCount;
		playerCellInfo[livePlayerCellCount].ai = cellAI;
		playerCellInfo[livePlayerCellCount].color = color;
		
		++livePlayerCellCount;
	}
	
	void tick()
	{
		// 0. Accelerate player cells
		for (int playerIndex = 0; playerIndex < livePlayerCellCount; ++playerIndex) {
			const PlayerCellInfo* playerInfo = &playerCellInfo[playerIndex];
			Cell* playerCell = &cells[playerInfo.cellIndex];
			
			acceleratePlayerCell(*playerCell, playerInfo.ai);
		}
		
		// 1. Advance all cells and resolve cell-arena collisions
		for (int cellIndex = 0; cellIndex < liveCellCount; ++cellIndex) {
			Cell* cell = &cells[cellIndex];
			
			// Advance cell
			advanceCell(*cell);
			
			// Collide with arena walls
			collideCellWithArena(*cell);
		}
		
		// 2. Resolve cell-cell collisions
		for (int firstCellIndex = 0; firstCellIndex < liveCellCount; ++firstCellIndex) {
			Cell* firstCell = &cells[firstCellIndex];
			
			for (int secondCellIndex = firstCellIndex + 1; secondCellIndex < liveCellCount; ++secondCellIndex) {
				Cell* secondCell = &cells[secondCellIndex];
				
				// Collide with another cell
				collideCells(*firstCell, *secondCell);
				
				if (firstCell.isDead()) {
					defragmentCellPartitions(firstCellIndex);
					--firstCellIndex;
					break;
				}
				
				if (secondCell.isDead()) {
					defragmentCellPartitions(secondCellIndex);
					--secondCellIndex;
				}
			}
		}
		
		// 3. Finish simulation if all players are dead.
		if (livePlayerCellCount == 0) {
			state = State.FINISHED;
			return;
		}
		
		// 4. Finish simulation if there is one player standing.
		if (liveCellCount == 1) {
			state = State.FINISHED;
			return;
		}
	}
	
private:
	
	void acceleratePlayerCell(ref Cell playerCell, const CellAI playerCellAI)
	{
		import core.stdc.string : memcpy;
		import std.algorithm : sort;

		if (playerCellAI) {
			memcpy(playerViewCells, cells, Cell.sizeof * liveCellCount);
			
			//sort(playerViewCells, playerViewCells + liveCellCount, DistanceToPlayerComparator(playerCell));
			
			Vector acceleration = playerCellAI
				.calculateAcceleration(playerViewCells[0 .. liveCellCount]);
			acceleration.normalize();
			
			playerCell.velocity += settings.tickLength * acceleration;
		}
	}

	void advanceCell(ref Cell cell)
	{
		cell.position += cell.velocity * settings.tickLength;
	}
	
	bool isCellCollidingWithArena(const ref Cell cell) const
	{
		bool result = false;
		
		float distanceFromArenaCenter = (cell.position - settings.arenaCenter).length + cell.radius;
		if (settings.arenaRadius < distanceFromArenaCenter) {
			result = true;
		}
		
		return result;
	}

	void collideCellWithArena(ref Cell cell)
	{
		import gfm.math.vector : dot;

		if (isCellCollidingWithArena(cell)) {
			// Find the unit vector pointing away from the arena at the point of collision.
			Vector normal = cell.position - settings.arenaCenter;
			normal.normalize();
			
			// Pull the cell back into the arena, making sure it doesn't collide during the next tick.
			cell.position = settings.arenaCenter + (settings.arenaRadius - cell.radius - 0.000000000001) * normal;
			
			// Flip the normal. Now it points directly to the arena's center at the point of collision.
			normal = -normal;
			
			// Use the normal to reflect the cell's velocity.
			cell.velocity -= 2.0f * dot(normal, cell.velocity) * normal;
		}
	}
	
	bool areCellsColliding(const ref Cell lhs, const ref Cell rhs) const
	{
		bool result = false;
		
		if ((lhs.position - rhs.position).length < float.epsilon) {
			result = true;
		}
		
		return result;
	}

	void collideCells(ref Cell lhs, ref Cell rhs)
	{
		float cellCenterDistance = (lhs.position, rhs.position).length;
		if (cellCenterDistance < lhs.radius + rhs.radius + float.epsilon) {
			// The two cells are colliding. Determine who eats who.
			Cell* preyCell;
			Cell* hunterCell;
			if (lhs.radius < rhs.radius) {
				preyCell = &lhs;
				hunterCell = &rhs;
			} else {
				preyCell = &rhs;
				hunterCell = &lhs;
			}
			
			// We want the hunter and prey to be just incident after the bite and preserve the cell matter.
			// Solve the system of equations.
			// | 0 < hunter radius < new hunter radius
			// | 0 <= new prey radius < prey radius
			// | new hunter raduis + new prey radius = distance(hunter center, prey center)
			// | hunter area + prey area = new hunter area + new prey area
			
			float newPreyRadius = 0.5f * (cellCenterDistance - sqrt(2.0f * (hunterCell.radius * hunterCell.radius + preyCell.radius * preyCell.radius) - cellCenterDistance * cellCenterDistance)); 
			float newHunterRadius = cellCenterDistance - newPreyRadius - float.epsilon;
			
			float oldHunterArea = hunterCell.getArea();
			float newHunterArea = PI * newHunterRadius * newHunterRadius;
			
			float biteArea = newHunterArea - oldHunterArea;

			preyCell.radius = newPreyRadius;
			hunterCell.radius = newHunterRadius;
			hunterCell.velocity = (oldHunterArea * hunterCell.velocity + biteArea * preyCell.velocity) / newHunterArea;
		}
	}
	
	void defragmentCellPartitions(int deadCellIndex)
	{
		if (deadCellIndex < livePlayerCellCount) {
			
			// Reaplace the dead player cell with the last living one
			int lastLivingPlayerCellIndex = livePlayerCellCount - 1;
			if (deadCellIndex < lastLivingPlayerCellIndex) {
				cells[deadCellIndex] = cells[lastLivingPlayerCellIndex];
				playerCellInfo[deadCellIndex] = playerCellInfo[lastLivingPlayerCellIndex];
				playerCellInfo[deadCellIndex].cellIndex = deadCellIndex;
			}
			
			deadCellIndex = lastLivingPlayerCellIndex;
			
			--livePlayerCellCount;
		}
		
		// Replace the dead cell with the last living one
		int lastLivingCellIndex = liveCellCount - 1;
		if (deadCellIndex < lastLivingCellIndex) {
			cells[deadCellIndex] = cells[lastLivingCellIndex];
			cells[lastLivingCellIndex].radius = 0.0f;
		}
		
		--liveCellCount;
	}
}

