/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License
 * 2.0; you may not use this file except in compliance with the Elastic License
 * 2.0.
 */

package org.elasticsearch.compute.data;

// begin generated imports
$if(BytesRef)$
import org.apache.lucene.util.BytesRef;
$endif$
import org.apache.lucene.util.RamUsageEstimator;
import org.elasticsearch.common.io.stream.StreamOutput;
import org.elasticsearch.common.unit.ByteSizeValue;
import org.elasticsearch.common.util.BytesRefArray;
import org.elasticsearch.core.ReleasableIterator;
import org.elasticsearch.core.Releasables;

import java.io.IOException;
import java.util.BitSet;
// end generated imports

/**
 * Block implementation that stores values in a {@link $Type$ArrayVector}.
$if(BytesRef)$
 * Does not take ownership of the given {@link BytesRefArray} and does not adjust circuit breakers to account for it.
$endif$
 * This class is generated. Edit {@code X-ArrayBlock.java.st} instead.
 */
final class $Type$ArrayBlock extends AbstractArrayBlock implements $Type$Block {

    static final long BASE_RAM_BYTES_USED = RamUsageEstimator.shallowSizeOfInstance($Type$ArrayBlock.class);

    private final $Type$ArrayVector vector;

    $Type$ArrayBlock(
        $if(BytesRef)$BytesRefArray$else$$type$[]$endif$ values,
        int positionCount,
        int[] firstValueIndexes,
        BitSet nulls,
        MvOrdering mvOrdering,
        BlockFactory blockFactory
    ) {
        this(
            new $Type$ArrayVector(values, firstValueIndexes == null ? positionCount : firstValueIndexes[positionCount], blockFactory),
            positionCount,
            firstValueIndexes,
            nulls,
            mvOrdering
        );
    }

    private $Type$ArrayBlock(
        $Type$ArrayVector vector, // stylecheck
        int positionCount,
        int[] firstValueIndexes,
        BitSet nulls,
        MvOrdering mvOrdering
    ) {
        super(positionCount, firstValueIndexes, nulls, mvOrdering);
        this.vector = vector;
        assert firstValueIndexes == null
            ? vector.getPositionCount() == getPositionCount()
            : firstValueIndexes[getPositionCount()] == vector.getPositionCount();
    }

    static $Type$ArrayBlock readArrayBlock(BlockFactory blockFactory, BlockStreamInput in) throws IOException {
        final SubFields sub = new SubFields(blockFactory, in);
        $Type$ArrayVector vector = null;
        boolean success = false;
        try {
            vector = $Type$ArrayVector.readArrayVector(sub.vectorPositions(), in, blockFactory);
            var block = new $Type$ArrayBlock(vector, sub.positionCount, sub.firstValueIndexes, sub.nullsMask, sub.mvOrdering);
            blockFactory.adjustBreaker(block.ramBytesUsed() - vector.ramBytesUsed() - sub.bytesReserved);
            success = true;
            return block;
        } finally {
            if (success == false) {
                Releasables.close(vector);
                blockFactory.adjustBreaker(-sub.bytesReserved);
            }
        }
    }

    void writeArrayBlock(StreamOutput out) throws IOException {
        writeSubFields(out);
        vector.writeArrayVector(vector.getPositionCount(), out);
    }

    @Override
    public $Type$Vector asVector() {
        return null;
    }

$if(BytesRef)$
    @Override
    public OrdinalBytesRefBlock asOrdinals() {
        return null;
    }

$elseif(boolean)$
    @Override
    public ToMask toMask() {
        if (getPositionCount() == 0) {
            return new ToMask(blockFactory().newConstantBooleanVector(false, 0), false);
        }
        try (BooleanVector.FixedBuilder builder = blockFactory().newBooleanVectorFixedBuilder(getPositionCount())) {
            boolean hasMv = false;
            for (int p = 0; p < getPositionCount(); p++) {
                builder.appendBoolean(switch (getValueCount(p)) {
                    case 0 -> false;
                    case 1 -> getBoolean(getFirstValueIndex(p));
                    default -> {
                        hasMv = true;
                        yield false;
                    }
                });
            }
            return new ToMask(builder.build(), hasMv);
        }
    }
$endif$

    @Override
$if(BytesRef)$
    public BytesRef getBytesRef(int valueIndex, BytesRef dest) {
        return vector.getBytesRef(valueIndex, dest);
$else$
    public $type$ get$Type$(int valueIndex) {
        return vector.get$Type$(valueIndex);
$endif$
    }

    @Override
    public $Type$Block filter(int... positions) {
$if(BytesRef)$
        final BytesRef scratch = new BytesRef();
$endif$
        try (var builder = blockFactory().new$Type$BlockBuilder(positions.length)) {
            for (int pos : positions) {
                if (isNull(pos)) {
                    builder.appendNull();
                    continue;
                }
                int valueCount = getValueCount(pos);
                int first = getFirstValueIndex(pos);
                if (valueCount == 1) {
                    builder.append$Type$(get$Type$(first$if(BytesRef)$, scratch$endif$));
                } else {
                    builder.beginPositionEntry();
                    for (int c = 0; c < valueCount; c++) {
                        builder.append$Type$(get$Type$(first + c$if(BytesRef)$, scratch$endif$));
                    }
                    builder.endPositionEntry();
                }
            }
            return builder.mvOrdering(mvOrdering()).build();
        }
    }

    @Override
    public $Type$Block keepMask(BooleanVector mask) {
        if (getPositionCount() == 0) {
            incRef();
            return this;
        }
        if (mask.isConstant()) {
            if (mask.getBoolean(0)) {
                incRef();
                return this;
            }
            return ($Type$Block) blockFactory().newConstantNullBlock(getPositionCount());
        }
$if(BytesRef)$
        BytesRef scratch = new BytesRef();
$endif$
        try ($Type$Block.Builder builder = blockFactory().new$Type$BlockBuilder(getPositionCount())) {
            // TODO if X-ArrayBlock used BooleanVector for it's null mask then we could shuffle references here.
            for (int p = 0; p < getPositionCount(); p++) {
                if (false == mask.getBoolean(p)) {
                    builder.appendNull();
                    continue;
                }
                int valueCount = getValueCount(p);
                if (valueCount == 0) {
                    builder.appendNull();
                    continue;
                }
                int start = getFirstValueIndex(p);
                if (valueCount == 1) {
                    builder.append$Type$(get$Type$(start$if(BytesRef)$, scratch$endif$));
                    continue;
                }
                int end = start + valueCount;
                builder.beginPositionEntry();
                for (int i = start; i < end; i++) {
                    builder.append$Type$(get$Type$(i$if(BytesRef)$, scratch$endif$));
                }
                builder.endPositionEntry();
            }
            return builder.build();
        }
    }

    @Override
    public ReleasableIterator<$Type$Block> lookup(IntBlock positions, ByteSizeValue targetBlockSize) {
        return new $Type$Lookup(this, positions, targetBlockSize);
    }

    @Override
    public ElementType elementType() {
        return ElementType.$TYPE$;
    }

    @Override
    public $Type$Block expand() {
        if (firstValueIndexes == null) {
            incRef();
            return this;
        }
        if (nullsMask == null) {
            vector.incRef();
            return vector.asBlock();
        }

        // The following line is correct because positions with multi-values are never null.
        int expandedPositionCount = vector.getPositionCount();
        long bitSetRamUsedEstimate = Math.max(nullsMask.size(), BlockRamUsageEstimator.sizeOfBitSet(expandedPositionCount));
        blockFactory().adjustBreaker(bitSetRamUsedEstimate);

        $Type$ArrayBlock expanded = new $Type$ArrayBlock(
            vector,
            expandedPositionCount,
            null,
            shiftNullsToExpandedPositions(),
            MvOrdering.DEDUPLICATED_AND_SORTED_ASCENDING
        );
        blockFactory().adjustBreaker(expanded.ramBytesUsedOnlyBlock() - bitSetRamUsedEstimate);
        // We need to incRef after adjusting any breakers, otherwise we might leak the vector if the breaker trips.
        vector.incRef();
        return expanded;
    }

    private long ramBytesUsedOnlyBlock() {
        return BASE_RAM_BYTES_USED + BlockRamUsageEstimator.sizeOf(firstValueIndexes) + BlockRamUsageEstimator.sizeOfBitSet(nullsMask);
    }

    @Override
    public long ramBytesUsed() {
        return ramBytesUsedOnlyBlock() + vector.ramBytesUsed();
    }

    @Override
    public boolean equals(Object obj) {
        if (obj instanceof $Type$Block that) {
            return $Type$Block.equals(this, that);
        }
        return false;
    }

    @Override
    public int hashCode() {
        return $Type$Block.hash(this);
    }

    @Override
    public String toString() {
        return getClass().getSimpleName()
            + "[positions="
            + getPositionCount()
            + ", mvOrdering="
            + mvOrdering()
            + ", vector="
            + vector
            + ']';
    }

    @Override
    public void allowPassingToDifferentDriver() {
        vector.allowPassingToDifferentDriver();
    }

    @Override
    public BlockFactory blockFactory() {
        return vector.blockFactory();
    }

    @Override
    public void closeInternal() {
        blockFactory().adjustBreaker(-ramBytesUsedOnlyBlock());
        Releasables.closeExpectNoException(vector);
    }
}
