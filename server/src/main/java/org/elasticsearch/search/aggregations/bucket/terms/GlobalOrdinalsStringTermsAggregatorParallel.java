/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License
 * 2.0 and the Server Side Public License, v 1; you may not use this file except
 * in compliance with, at your election, the Elastic License 2.0 or the Server
 * Side Public License, v 1.
 */

package org.elasticsearch.search.aggregations.bucket.terms;

import org.apache.lucene.index.DocValues;
import org.apache.lucene.index.SortedDocValues;
import org.apache.lucene.index.SortedSetDocValues;
import org.apache.lucene.search.CollectorManager;
import org.elasticsearch.common.CheckedSupplier;
import org.elasticsearch.common.util.LongArray;
import org.elasticsearch.search.DocValueFormat;
import org.elasticsearch.search.aggregations.AggregationExecutionContext;
import org.elasticsearch.search.aggregations.Aggregator;
import org.elasticsearch.search.aggregations.AggregatorFactories;
import org.elasticsearch.search.aggregations.BucketOrder;
import org.elasticsearch.search.aggregations.CardinalityUpperBound;
import org.elasticsearch.search.aggregations.LeafBucketCollector;
import org.elasticsearch.search.aggregations.support.AggregationContext;
import org.elasticsearch.search.aggregations.support.ValuesSource;
import java.io.IOException;
import java.util.Map;
import java.util.function.Function;
import java.util.function.LongPredicate;
import java.util.function.LongUnaryOperator;

import static org.apache.lucene.index.SortedSetDocValues.NO_MORE_ORDS;

/**
 * concurrent.
 * one aggregator one slice.
 */
public class GlobalOrdinalsStringTermsAggregatorParallel extends GlobalOrdinalsStringTermsAggregator{
    protected int segmentsWithoutValues = 0;

    public GlobalOrdinalsStringTermsAggregatorParallel(String name, AggregatorFactories factories, Function<GlobalOrdinalsStringTermsAggregator, ResultStrategy<?, ?, ?>> resultStrategy, ValuesSource.Bytes.WithOrdinals valuesSource, CheckedSupplier<SortedSetDocValues, IOException> valuesSupplier, BucketOrder order, DocValueFormat format, BucketCountThresholds bucketCountThresholds, LongPredicate acceptedOrds, AggregationContext context, Aggregator parent, boolean remapGlobalOrds, SubAggCollectionMode collectionMode, boolean showTermDocCountError, CardinalityUpperBound cardinality, Map<String, Object> metadata) throws IOException {
        super(name, factories, resultStrategy, valuesSource, valuesSupplier, order, format, bucketCountThresholds, acceptedOrds, context, parent, remapGlobalOrds, collectionMode, showTermDocCountError, cardinality, metadata);
        context.bigArrays();
    }

    @Override
    public LeafBucketCollector getLeafCollector(AggregationExecutionContext aggCtx, LeafBucketCollector sub) throws IOException {
        final SortedSetDocValues segmentOrds = valuesSource.ordinalsValues(aggCtx.getLeafReaderContext());
        if (segmentOrds.getValueCount() == 0) {
            segmentsWithoutValues++;
            return LeafBucketCollector.NO_OP_COLLECTOR;
        }
        assert sub.isNoop();
        final SortedDocValues singleValues = DocValues.unwrapSingleton(segmentOrds);
        // Dense mode doesn't support include/exclude so we don't have to check it here.
        if (singleValues != null) {
            return new LeafBucketCollectorParallel(valuesSource.globalOrdinalsMapping(aggCtx.getLeafReaderContext()),
                segmentOrds){
                @Override
                public void collect(int doc, long owningBucketOrd) throws IOException {
                    assert owningBucketOrd == 0;
                    if (false == singleValues.advanceExact(doc)) {
                        return;
                    }
                    int ord = singleValues.ordValue();
                    int docCount = docCountProvider.getDocCount(doc);
                    segmentDocCounts.increment(ord + 1, docCount);
                }
            };
        }
        return new LeafBucketCollectorParallel(valuesSource.globalOrdinalsMapping(aggCtx.getLeafReaderContext()),
            segmentOrds){
            @Override
            public void collect(int doc, long owningBucketOrd) throws IOException {
                assert owningBucketOrd == 0;
                if (false == segmentOrds.advanceExact(doc)) {
                    return;
                }
                for (long segmentOrd = segmentOrds.nextOrd(); segmentOrd != NO_MORE_ORDS; segmentOrd = segmentOrds.nextOrd()) {
                    int docCount = docCountProvider.getDocCount(doc);
                    segmentDocCounts.increment(segmentOrd + 1, docCount);
                }
            }
        };

    }

    abstract class LeafBucketCollectorParallel extends LeafBucketCollector{
        public LongUnaryOperator ordinalMapping;
        public LongArray segmentDocCounts;
        public SortedSetDocValues segmentOrds;

        LeafBucketCollectorParallel(LongUnaryOperator ordinalMapping, SortedSetDocValues segmentOrds) {
            this.ordinalMapping = ordinalMapping;
            this.segmentOrds = segmentOrds;
            this.segmentDocCounts = bigArrays().newLongArray(segmentOrds.getValueCount(), true);
        }



    }

//    public static CollectorManager<GlobalOrdinalsStringTermsAggregatorParallel, Void> createSharedManager(){
//
//    }

}
