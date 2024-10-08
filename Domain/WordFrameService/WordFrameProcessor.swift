//
//  WordFrameProcessor.swift
//  Quran
//
//  Created by Mohamed Afifi on 4/22/16.
//

import QuranGeometry

public struct WordFrameProcessor {
    // MARK: Lifecycle

    public init() {
    }

    // MARK: Public

    public func processWordFrames(_ frames: [WordFrame]) -> WordFrameCollection {
        guard !frames.isEmpty else {
            return WordFrameCollection(lines: [])
        }

        // group by line
        let framesByLines = Dictionary(grouping: frames, by: { $0.line })
        var lines = framesByLines
            .sorted { $0.key < $1.key }
            .map { _, wordFrames in wordFrames }

        normalize(&lines)
        alignFramesVerticallyInEachLine(&lines)
        unionLinesVertically(&lines)
        unionFramesHorizontallyInEachLine(&lines)
        alignLineEdges(&lines)

        return WordFrameCollection(lines: lines.map { WordFrameLine(frames: $0) })
    }

    // MARK: Private

    private func normalize(_ lines: inout [[WordFrame]]) {
        for i in 0 ..< lines.count {
            for j in 0 ..< lines[i].count {
                lines[i][j].normalize()
            }
        }
    }

    private func alignFramesVerticallyInEachLine(_ lines: inout [[WordFrame]]) {
        // align vertically each line
        for i in 0 ..< lines.count {
            lines[i] = WordFrame.alignedVertically(lines[i])
        }
    }

    private func unionLinesVertically(_ lines: inout [[WordFrame]]) {
        // union each line with its neighbors
        for i in 0 ..< lines.count - 1 {
            // Create temporary copies
            var topFrames = lines[i]
            var bottomFrames = lines[i + 1]

            WordFrame.unionVertically(top: &topFrames, bottom: &bottomFrames)

            // Assign the modified copies back to the original array
            lines[i] = topFrames
            lines[i + 1] = bottomFrames
        }
    }

    private func unionFramesHorizontallyInEachLine(_ lines: inout [[WordFrame]]) {
        for lineIndex in 0 ..< lines.count {
            // Sort frames in the current line based on minX to ensure they are in decreasing order
            lines[lineIndex].sort(by: { $0.minX > $1.minX })

            for frameIndex in 0 ..< lines[lineIndex].count - 1 {
                var leftFrame = lines[lineIndex][frameIndex + 1]
                var rightFrame = lines[lineIndex][frameIndex + 0]

                // Ensure the frames touch each other without gaps or overlaps
                WordFrame.unionHorizontally(leftFrame: &leftFrame, rightFrame: &rightFrame)

                // Update the frames in the current line
                lines[lineIndex][frameIndex + 1] = leftFrame
                lines[lineIndex][frameIndex + 0] = rightFrame
            }
        }
    }

    private func alignLineEdges(_ lines: inout [[WordFrame]]) {
        // align the edges
        var rightEdge = lines.map { $0[0] }
        var leftEdge = lines.map { $0[$0.count - 1] }
        WordFrame.unionLeftEdge(&leftEdge)
        WordFrame.unionRightEdge(&rightEdge)

        for i in 0 ..< lines.count {
            lines[i][0] = rightEdge[i]
            lines[i][lines[i].count - 1] = leftEdge[i]
        }
    }
}
