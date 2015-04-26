package org.apache.lucene.analysis.tr;

/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import org.apache.lucene.analysis.TokenStream;
import org.apache.lucene.analysis.miscellaneous.StemmerOverrideFilter;
import org.apache.lucene.analysis.util.ResourceLoader;
import org.apache.lucene.analysis.util.ResourceLoaderAware;
import org.apache.lucene.analysis.util.TokenFilterFactory;

import java.io.File;
import java.io.IOException;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import zemberek.morphology.apps.TurkishMorphParser;
import zemberek.morphology.parser.MorphParse;

/**
 * Factory for {@link TRMorphStemFilterFactory}.
 * <pre class="prettyprint">
 * &lt;fieldType name="text_tr_morph" class="solr.TextField" positionIncrementGap="100"&gt;
 * &lt;analyzer&gt;
 * &lt;tokenizer class="solr.StandardTokenizerFactory"/&gt;
 * &lt;filter class="solr.ApostropheFilterFactory"/&gt;
 * &lt;filter class="solr.TurkishLowerCaseFilterFactory"/&gt;
 * &lt;filter class="org.apache.lucene.analysis.tr.TRMorphStemFilterFactory" lookup="/Applications/foma/flookup" fst="/Volumes/datadisk/Desktop/TRmorph-master/stem.fst"/&gt;
 * &lt;/analyzer&gt;
 * &lt;/fieldType&gt;</pre>
 */
public class TRMorphStemFilterFactory extends TokenFilterFactory implements ResourceLoaderAware {


    private StemmerOverrideFilter.StemmerOverrideMap cache;
    boolean ignoreCase = false;
    private final String cacheFiles;
    private final String strategy;


    public TRMorphStemFilterFactory(Map<String, String> args) {
        super(args);
 
        cacheFiles = get(args, "cache");
        strategy = get(args, "strategy", "minLength");

        if (!args.isEmpty())
            throw new IllegalArgumentException("Unknown parameters: " + args);

        if (!"minLength".equals(strategy) && !"maxLength".equals(strategy))
            throw new IllegalArgumentException("unknown strategy " + strategy);

    }

    @Override
    public void inform(ResourceLoader loader) throws IOException {
        if (cacheFiles != null) {
            List<String> files = splitFileNames(cacheFiles);
            if (files.size() > 0) {
                StemmerOverrideFilter.Builder builder = new StemmerOverrideFilter.Builder(ignoreCase);
                for (String file : files) {
                    List<String> list = getLines(loader, file.trim());
                    for (String line : list) {
                        builder.add(line, TRMorphStemFilter.stem(line, strategy));
                    }
                }
                cache = builder.build();
            }
        }
    }

    @Override
    public TokenStream create(TokenStream input) {
        TRMorphStemFilter filter = new TRMorphStemFilter(input, strategy);
        if (cache != null) {
            filter.setCache(cache);
        }
        return filter;
    }
    
   
}
