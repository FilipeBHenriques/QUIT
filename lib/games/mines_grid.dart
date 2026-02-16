import 'package:flame/components.dart';
import 'dart:math' as math;
import 'mines_constants.dart';
import 'mines_tile.dart';

// ============================================================================
// MINES GRID COMPONENT
// ============================================================================

class MinesGrid extends PositionComponent {
  final Function(bool hitBomb, int diamondsFound) onTileRevealed;
  final Vector2 gameSize;

  List<List<MinesTile>> tiles = [];
  List<Vector2> bombPositions = [];
  int diamondsRevealed = 0;
  bool gameOver = false;

  MinesGrid({required this.onTileRevealed, required this.gameSize})
    : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _initializeGrid();
  }

  void _initializeGrid() {
    // Calculate grid dimensions based on screen size
    final gridWidth = gameSize.x * MinesConstants.gridWidthPercent;
    final tileSize = gridWidth / MinesConstants.gridSize;
    final spacing = tileSize * MinesConstants.tileSpacingPercent;
    final actualTileSize = tileSize - spacing;

    // Set position to center of screen
    position = Vector2(
      gameSize.x * MinesConstants.gridCenterX,
      gameSize.y * MinesConstants.gridCenterY,
    );

    // Generate bomb positions
    _generateBombPositions();

    // Create tiles
    tiles = [];
    for (int row = 0; row < MinesConstants.gridSize; row++) {
      List<MinesTile> rowTiles = [];
      for (int col = 0; col < MinesConstants.gridSize; col++) {
        // Calculate tile position
        final tileX = (col - MinesConstants.gridSize / 2 + 0.5) * tileSize;
        final tileY = (row - MinesConstants.gridSize / 2 + 0.5) * tileSize;

        // Check if this position has a bomb
        final isBomb = bombPositions.any((pos) => pos.x == col && pos.y == row);

        final tile = MinesTile(
          row: row,
          col: col,
          type: isBomb ? TileType.bomb : TileType.diamond,
          onTap: _onTileTapped,
          tileSize: actualTileSize,
          position: Vector2(tileX, tileY),
        );

        rowTiles.add(tile);
        add(tile);
      }
      tiles.add(rowTiles);
    }
  }

  void _generateBombPositions() {
    bombPositions.clear();
    final random = math.Random();
    final positions = <Vector2>[];

    // Generate all possible positions
    for (int row = 0; row < MinesConstants.gridSize; row++) {
      for (int col = 0; col < MinesConstants.gridSize; col++) {
        positions.add(Vector2(col.toDouble(), row.toDouble()));
      }
    }

    // Shuffle and take first N positions for bombs
    positions.shuffle(random);
    bombPositions = positions.take(MinesConstants.bombCount).toList();
  }

  void _onTileTapped(int row, int col) {
    if (gameOver) return;

    final tile = tiles[row][col];
    if (tile.state != TileState.hidden) return;

    if (tile.type == TileType.bomb) {
      // Hit a bomb - game over
      tile.explode();
      gameOver = true;

      // Reveal all other bombs after a delay
      Future.delayed(
        Duration(milliseconds: MinesConstants.revealAnimationDuration),
        _revealAllBombs,
      );

      onTileRevealed(true, diamondsRevealed);
    } else {
      // Found a diamond
      tile.reveal();
      diamondsRevealed++;

      onTileRevealed(false, diamondsRevealed);

      // Check if all diamonds found
      if (diamondsRevealed >= MinesConstants.diamondCount) {
        gameOver = true;
      }
    }
  }

  void _revealAllBombs() {
    for (var row in tiles) {
      for (var tile in row) {
        if (tile.type == TileType.bomb && tile.state == TileState.hidden) {
          tile.reveal();
        }
      }
    }
  }

  void reset() {
    // Remove all existing tiles
    for (var row in tiles) {
      for (var tile in row) {
        remove(tile);
      }
    }

    // Reset state
    tiles.clear();
    bombPositions.clear();
    diamondsRevealed = 0;
    gameOver = false;

    // Reinitialize
    _initializeGrid();
  }
}
