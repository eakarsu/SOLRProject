var querystring = require("querystring"),
        fs = require("fs"),
        formidable = require("formidable");
var http = require('http');
var requestmod = require('request');
var util = require("util");
var express = require('express'); // bring in the the express api
var fs = require('fs'); // bring in the file system api
var url = require('url');
var qs = require('querystring');
var basepath = "/arabul?";
var mustache = require('mustache'); // bring in mustache template engine
var swig = require('swig');

var maxflen = 256;
var pblock = 20;
var resultspage = "../resources/aramasonuclari.html";
var startpage = "../resources/index.html";

//The url we want is: 'www.random.org/integers/?num=1&min=1&max=10&col=1&base=10&format=plain&rnd=new'

var host = 'localhost';
var port = '8080';
var path = '/migrossolr/ProductsTRMorphTestIst/select?wt=json&indent=true';
var rankingProcess = require("./rankingProcess");
var campaignInfo = require("./campaignInfo");

function test ()
{
    var list = rankingProcess.flList;
    for (field in list){
        console.log ("debug field="+field+" = "+list[field]);
    }
};

function findFacetingValues (solrdata,customerid,storeid,query)
{
    /*
    var facetNames=[
       'IsMCCProduct_STOREID', //Money Club indirimli urunler
       'UnitSymbol', //Birim
       'IsMigroskop', //Migroskop urunler
       'BrandName', //Markalar
       'PathLevel2', //Reyonlar
       'CustomersPurchased', //eski siparislerim
       'CustomersFavourite', //Favoro urunlerim
       'InPromotion_STOREID' //kampanyali urunler
   ];
     */    
    var facetQueryUrlInit = rankingProcess.prepareBrowseQuery(query);
    var facets = {};
       
     //Favori urunlerim veya eski siparislerim grubu
    if (typeof solrdata.facet_counts.facet_queries !== 'undefined'){
        var facetQueriesData = solrdata.facet_counts.facet_queries;
        for (var prop in facetQueriesData){
            var facetQueryUrl = facetQueryUrlInit;
            var facetName = "";
            if (prop.match(/CustomersFavourite/) ){
                facetName = "CustomersFavourite";
            }else if (prop.match(/CustomersPurchased/)){
                facetName = "CustomersPurchased";
            }
            if (facetName.length > 0){
                var facetCount = facetQueriesData[prop];
                facetQueryUrl = facetQueryUrl+ facetName+"="+customerid;
                facets[facetName] = {facetCount:facetCount,facetQueryUrl:facetQueryUrl};
                console.log ("Aded facet query results : facetName="+facetName+":"+facetCount+": facetURL:"+facetQueryUrl);
            }        
         }
    }
    
    var facetFieldsData = solrdata.facet_counts.facet_fields;
    for (var facetName in facetFieldsData){
        var facetQueryUrl = facetQueryUrlInit;
        
        var facetVals = facetFieldsData[facetName];
        facetName = facetName.replace(/_.*/,"");
         
        var facetCount = 0;
        
        //kampanyali urunler,migroskop urunleri veya money club indirimli urunler
        if (facetName.match(/InPromotion|IsMigroskop|IsMCCProduct/)){
            for (var fp in facetVals){
                if (facetVals[fp] === "true"){
                    facetCount = facetVals[parseInt(fp)+1];
                    break;
                }
            };
                       
            if (facetName.match(/IsMigroskop/)){
                facetQueryUrl = facetQueryUrl+facetName+"=true";
            }else{
                facetQueryUrl = facetQueryUrl+facetName+"_"+storeid+"=true";
            }
            facets[facetName] = {facetCount:facetCount,facetQueryUrl:facetQueryUrl};
            console.log ("Aded facet query results : facetName="+facetName+":"+facetCount+": facetURL:"+facetQueryUrl);
        }
        else{ 
            var array = [];
            for (var j=0;j<facetVals.length;j+=2){
                var facetQueryUrl = facetQueryUrlInit;
                var facetValue = facetVals[j];
                var facetCount = facetVals[j+1];
                var facetQueryUrl = facetQueryUrl+facetName+"=\""+facetValue+"\"";
                array[j/2] = {facetValue:facetValue,facetCount:facetCount,facetQueryUrl:facetQueryUrl};
                //take only first 30 elements
                if (j/2 == 30){
                    break;
                }
                
            }
            facets[facetName] = array;
        }
        
    }  
    
    /*
         * "UnitVal_GR":{
        "counts":[
          "0.0",2,
          "100.0",4,
          "200.0",4,
          "300.0",1,
          "500.0",3,
          "600.0",1,
          "700.0",2,
          "800.0",2],
        "gap":100.0,
        "start":0.0,
        "end":2000.0},
         */
        var array = [];
        var facetRanges = solrdata.facet_counts.facet_ranges;
        //facetName:UnitVal_GR
        for (var facetName in facetRanges){
            
            var facetTuple = facetRanges[facetName];
             var counts = facetTuple["counts"];
             if (counts.length === 0){
                 continue;
             }
             var facetSymb = facetName.replace(/.*_/,"");
             var gap = parseFloat(facetTuple["gap"]);
             for (var x=0;x<counts.length; x+= 2){
                 var lb = parseFloat(counts[x]);
                 var facetCount = parseInt(counts[x+1]);
                 var ub = lb+gap;
                 var rangeExpr = lb +" - "+ub+" "+facetSymb;                 
                 var facetQueryUrl = facetQueryUrlInit+"UnitExpr=\""+rangeExpr+"\"";
                 var triple = {facetValue:rangeExpr,facetCount:facetCount,facetQueryUrl:facetQueryUrl};
                 array.push(triple);
                 console.log ("Adde facet range url="+facetQueryUrl);
             }          
        }
        facets['UnitExpr'] = array;
        
    return facets;
} 

function setupResults(body,storeid,custsegmentid,query) {
        
    var solrdata = JSON.parse(body);
    var docs = solrdata.response.docs;
    var numFound = solrdata.response.numFound;
    var start = solrdata.response.start;
    var highs = solrdata.highlighting;
    var responseHeader = solrdata.responseHeader;
    var queryKeyword = query.q;
    
    
    var debugData = parseDebugExplain(solrdata);
    
    var rows = new Array();
    var flist = rankingProcess.getFL();
    
    var customerid = query.customerid;
    var facets = findFacetingValues(solrdata,customerid,storeid,query);
    
    //swap first and third value if keyword macthes to a campaign
    if ((docs.length >0 )&& (docs[0]['IsInCampaign'] || docs[0]['IsInCampaignBrand']||docs[0]['IsInCampaignCategory']) && docs.length >= 3 ){
        console.log ("Swapping 1. and 3. document");
        var temp = docs[2];
        docs[2] = docs[0];
        docs[0] = temp;

        temp = docs[1];
        docs[1] = docs[0];
        docs[0] = temp;
    }
    
    for (j = 0; j < docs.length; j++) {
        rows[j] = {};
        for (k in flist){
            var field = flist[k];
            var newFieldName = field.replace(/SEGMENTID/g,custsegmentid).replace(/STOREID/g,storeid).replace(/:.*/g,"");
            var fieldVal = docs[j][newFieldName];
            if (newFieldName === 'ProductMoreDetail'){
                fieldVal = fieldVal.replace(/\r\n|\n/g, '');
            }
            
            var newFieldName2 = newFieldName.replace(/_[0-9]+/,"");   
            rows[j][newFieldName2] = fieldVal;
            //console.log ("received field="+newFieldName+" = "+rows[j][newFieldName2]);
        }
        //add debug data
        var pid = rows[j]['ProductID'];
        rows[j]['debugData'] = debugData[pid];
        
    } ;
    return {rows: rows, numFound: numFound, start: start, qtime: responseHeader.QTime,facets:facets};
}

function setupPagination(start, query, numFound, requesturl) {
    var nexturl = true, prevurl = true;
    var pages = new Array();
    var startindex = query.startindex, endindex = query.endindex;
     
    var customerid = query.customerid;
    var storeid = query.storeid;
    
    var target = start / pblock;
    console.log("incomng counters==" + startindex + ":" + endindex +
            " qs =" + requesturl);


    if (target > endindex) {
        endindex++;
        startindex++;
    } else if (target < startindex) {
        startindex--;
        endindex--;
    }

    console.log("new counters==" + startindex + ":" + endindex);

    //extract only query string q=.*&
    var pat = new RegExp(/q=[^&]+&/);
    var queryparam = requesturl.match(pat);
    queryparam = queryparam[0];
    var partialpath = rankingProcess.prepareBrowseQuery (query);// basepath + queryparam;

    /* 
     // replace start=229893 with empty string
     var regex=/start=[0-9]+/;
     var querywostart = requesturl.replace(regex,"");
     console.log ("querywostart="+querywostart);
    */

    var startblock = startindex * pblock;
    var endblock = endindex * pblock;
    console.log("setup indexes if "+endblock +":"+numFound+" startblock="+startblock);
    
    var finalIndex = Math.ceil(numFound/pblock);
    
    if ((startblock <= numFound && endblock >=numFound) || numFound > endblock) {
        startindex = parseInt(startindex);
        endindex = parseInt(endindex);
        for (var j = startindex; j <= endindex && j<finalIndex; j++) {
            pages[j - startindex] = {index: j, url: (partialpath + "start=" + (j * pblock))};
        }
    }


    if (startindex > 1) {
        prevurl = partialpath + "start=" + ((parseInt(startindex) - 1) * pblock);
    } else {
        prevurl = false;
    }

    if (endblock <= numFound) {
        var sval = ((parseInt(endindex) + 1) * pblock);
        console.log("sval=" + sval);
        nexturl = partialpath + "start=" + sval;
    } else {
        nexturl = false;
    }
    console.log("prevurl=" + prevurl + " nexturl=" + nexturl);

    return {prevurl: prevurl, nexturl: nexturl, pageindexes: pages,
        startindex: startindex, endindex: endindex, currentindex: target};
}
;

function buildPage(response, body, query, requesturl,solrURL) {
    var storeid = query.storeid;
    var custsegmentid = query.custsegmentid;
            
    var results = setupResults(body,storeid,custsegmentid,query);
    var rows = results.rows;

    console.log("buildPage:numFound=" + results.numFound + " start=" + results.start);
 
    var pgs = setupPagination(results.start, query, results.numFound, requesturl);

    var solrfields = [];
    for (f in rankingProcess.flList){
        solrfields.push(f.replace(/SEGMENTID/g,custsegmentid).replace(/STOREID/g,storeid));
    }
    
    var showsolrreq = query.showsolrreq;
    var solrURLText = "";
    if (showsolrreq === "on"){
        solrURLText = "SOLR Query sent : "+solrURL;
    }
    
    var facets = rankingProcess.getFacetQueryParam (query);
    var facetFilters = [];
    for (var prop in facets){
        var propVal = facets[prop];//.replace(/"/g,"");
        console.log("Addigin filter :"+propVal);
        if (propVal.constructor === Array){
            for (var index in propVal){
                facetFilters.push(prop+"="+propVal[index]);
            }
        }
        else    
            facetFilters.push(prop+"="+propVal);
    } 
    var prevFilters = facetFilters.join("&");
    
    var rData = {records: rows, nexturl: pgs.nexturl, prevurl: pgs.prevurl, pageindexes: pgs.pageindexes,
        startindex: pgs.startindex, endindex: pgs.endindex,
        qtime: results.qtime, numFound: results.numFound, queryString: query.q, currentindex: pgs.currentindex,
        customerid:query.customerid,storeid:query.storeid,custsegmentid:query.custsegmentid,discountlevel:query.discountlevel,solrURL:solrURLText,
        facets:results.facets,prevFilters:prevFilters};
  
    /*var page = fs.readFileSync(resultspage, "utf8"); // bring in the HTML file
     var html = mustache.to_html(page, rData); // replace all of the data
     */

    var template = swig.compileFile(__dirname + "/" + resultspage);
    var html = template(rData);

    //console.log(body); 

    response.writeHead(200, {"Content-Type": "text/html;charset=UTF-8"});
    response.write(html);
    response.end();


};


function solrdata(presponse, request) {
    console.log("Request handler 'solrdata' was called for " + request.url);
    var queryData = url.parse(request.url, true).query;
    
    var solrURL = rankingProcess.prepareBQOnlySOLRQuery2 (queryData);
    requestmod(solrURL, function (error, response, body) {
        buildPage(presponse, body, queryData, request.url,solrURL);

    });

}
 
     /**    {psi: 176227,
            pmn: "MİLUPA ORGANİK ŞEFTALİ ELMA KAVANOZ MAMASI 125 GR",
            price: 2.15,
            mccPrice: 0.0,
            actionPrice: 0.0,
            calculatedPrice: 2.15,
            category: "Meyve Suyu",
            brand: "Dimes",
            unit: "1 L",
            onStock: true,
            myFavorites: true,
            myOldOrders: false,
            inPromotion: true,
            migroskop: false,
            mcc: true}
filters: [
        {k: "myFavorites", v: 4},

        {k: "myOldOrders", v: 2},

        {k: "inPromotion", v: 8},

        {k: "migroskop", v: 7},

        {k: "mcc", v: 5},

        {
            k: "categories", v: [
            {"n": "çay kahve", c: 3},
            {"n": "unlu mamuller", c: 2}
        ]
        },

        {
            k: "brands", v: [
            {"n": "cappy", c: 24},
            {"n": "elma", c: 21},
            {"n": "migros", c: 2}
        ]
        },

        {
            k: "units", v: [
            {"n": "GR", c: 5},
            {"n": "ML", c: 3}
        ]
        },

        {
            k: "productProperty", v: [
            {"n": "?", c: '?'},
            {"n": "?", c: '?'}
        ]
        }
    ]
             */
            /*
             * "offset": 50,
    "limit": 100,
    "filterResultLimit": 5,
*/

function reformatSolrResultFirst (solrBody,postBody)
{
        var migrosResp = {};
        var solrdata = JSON.parse(solrBody);
        var solrDocs = solrdata.response.docs;
        migrosResp['totalFound'] = solrdata.response.numFound;
        var docs = new Array();
        var flist = rankingProcess.getFL();
                 
        var custsegmentid = postBody['customerSegment'];
        var customerid = postBody["customerId"];
        var storeid = postBody["store"];
        
        var filterResultLimit = postBody['filterResultLimit'];
        
        for (j = 0; j < solrDocs.length; j++) {
            var row = {};
            docs[j] = {};
            for (k in flist){
                var field = flist[k];
                var fieldName = field.replace(/SEGMENTID/g,custsegmentid).replace(/STOREID/g,storeid).replace(/:.*/g,"");
                var fieldVal = solrDocs[j][fieldName];
                if (fieldName === 'ProductMoreDetail'){
                    fieldVal = fieldVal.replace(/\r\n|\n/g, '');
                } 

                var fieldName = fieldName.replace(/_[0-9]+/,""); 
                row[fieldName] = fieldVal;
            }
            /*for (var prop  in row){
                console.log (prop+":"+row[prop]);
            }*/
             
             
            docs[j]['psi'] = row['PSIID'];
            docs[j]['pmn'] = row['ProductModelName'];
            docs[j]['calculatedPrice'] = row['Price'];
            docs[j]['category'] = row['PathLevel2'];
            docs[j]['brand'] = row['BrandName'];
            docs[j]['unit'] = row['UnitExpr'];//row['UnitSymbol'];
            docs[j]['onStock'] = row['InStock'];
            docs[j]['inPromotion']= row['InPromotion'];
            docs[j]['myFavorites'] = row['myFavorites'];
            docs[j]['myOldOrders'] = row['myOldOrders'];
            docs[j]['migroskop'] = row['IsMigroskop'];
            docs[j]['mcc'] = row['IsMCCProduct'];
            docs[j]['pid'] = row['ProductID'];
            docs[j]['score'] = row['score'];
        } ;
        
        migrosResp.docs = docs;
        var facets = findFacetingValues(solrdata,customerid,storeid,{});

        
       // make default value of those to 0 : inPromotion, myOldOrders, migroskop 
        if (typeof facets.CustomersPurchased.facetCount === 'undefined'){
            facets.CustomersPurchased.facetCount = 0;
        }
        if (typeof facets.InPromotion.facetCount === 'undefined'){
            facets.InPromotion.facetCount = 0;
        }
        if (typeof facets.IsMigroskop.facetCount === 'undefined'){
            facets.IsMigroskop.facetCount = 0;
        }
        if (typeof facets.IsMCCProduct.facetCount === 'undefined'){
            facets.IsMCCProduct.facetCount = 0;
        }
        var filters = new Array();
        filters [0] = {k: "myFavorites", v: facets.CustomersFavourite.facetCount};
        filters [1] = {k: "myOldOrders", v: facets.CustomersPurchased.facetCount};
        filters [2] = {k: "inPromotion", v: facets.InPromotion.facetCount};
        filters [3] = {k: "migroskop", v: facets.IsMigroskop.facetCount};
        filters [4] = {k: "mcc", v: facets.IsMCCProduct.facetCount};

        var categories = [];
        
        for (var j=0;j<Math.min(facets.PathLevel2.length,filterResultLimit);j++){
            categories.push({"n": facets.PathLevel2[j].facetValue, c: facets.PathLevel2[j].facetCount});
        }
        filters[5] = {k:"categories",v:categories};

        var brands = [];
        for (var j=0;j<Math.min(facets.BrandName.length,filterResultLimit);j++){
            brands.push({"n": facets.BrandName[j].facetValue, c: facets.BrandName[j].facetCount});
        }
        filters[6] = {k:"brands",v:brands};

        var units = [];
        fillUnitFacetRanges(facets,units);
        filters[7] = {k:"units",v:units};

        var properties = [];
        for (var j=0;j<Math.min(facets.ProductProperty.length,filterResultLimit);j++){
            properties.push({"n": facets.ProductProperty[j].facetValue, c: facets.ProductProperty[j].facetCount});
        }
        filters[8] = {k:"productProperties",v:properties};

        migrosResp.filters = filters;
        
        //parse debug output
        var debugData = parseDebugExplain(solrdata);
        //Use PSI id instead of products
        //debugExplainResult[pid] = {"score":totalScore,"details":scoreArray};
        var debugDataPsi = {};
        for (var j = 0; j < solrDocs.length; j++) {
            var psi = docs[j]['psi'];
            var pid = docs[j]['pid'];
            debugDataPsi[psi] = {};
            debugDataPsi[psi] = debugData[pid];
            console.log (psi +" <- "+pid);
        }
        
       
        //migrosResp.debugData = debugData;
        migrosResp.debugData = debugDataPsi;
        
        return migrosResp;
    
};

function reformatSolrResult (solrBody,postBody)
{
        var migrosResp = {};
        var solrdata = JSON.parse(solrBody);
        var solrDocs = solrdata.response.docs;
        migrosResp['totalFound'] = solrdata.response.numFound;
        var docs = new Array();
        var flist = rankingProcess.getFL();
                 
        var custsegmentid = postBody['customerSegment'];
        var customerid = postBody["customerId"];
        var storeid = postBody["store"];
        
        var filterResultLimit = postBody['filterResultLimit'];
        var debugPar = postBody["debug"];
    
        var debug = false;
        if (typeof debugPar !== 'undefined' && debugPar){
            debug = true;
        }
       console.log ("DEBUG her ein POST:"+debug);
       
        for (j = 0; j < solrDocs.length; j++) {
            docs[j] = {};
            for (k in flist){
                var field = flist[k];
                var fieldName = field.replace(/SEGMENTID/g,custsegmentid).replace(/STOREID/g,storeid).replace(/:.*/g,"");
                var fieldVal = solrDocs[j][fieldName];
                if (fieldName === 'ProductMoreDetail'){
                    fieldVal = fieldVal.replace(/\r\n|\n/g, '');
                } 

                var fieldName = fieldName.replace(/_[0-9]+/,""); 
                if (!debug){
                    if (fieldName === "PSIID"){
                      docs[j]["PSIID"] = fieldVal;
                    }
                    else if (fieldName === "ProductID"){
                        docs[j]["ProductID"] = fieldVal; 
                    }
                }
                else{
                    docs[j][fieldName] = fieldVal;
                }
            }
            /*for (var prop  in row){
                console.log (prop+":"+row[prop]);
            }*/
             
        } ;
        
        //swap first and third value if keyword macthes to a campaign
        if ((docs.length >0 )&&(docs[0]['IsInCampaign'] || docs[0]['IsInCampaignBrand']||docs[0]['IsInCampaignCategory']) && docs.length >= 3 ){
            console.log ("Swapping 1. and 3. document ");
            var temp = docs[2];
            docs[2] = docs[0];
            docs[0] = temp;
        }
    
        migrosResp.docs = docs;
        var facets = findFacetingValues(solrdata,customerid,storeid,{});

        
       // make default value of those to 0 : inPromotion, myOldOrders, migroskop 
        if (typeof facets.CustomersPurchased.facetCount === 'undefined'){
            facets.CustomersPurchased.facetCount = 0;
        }
        if (typeof facets.InPromotion.facetCount === 'undefined'){
            facets.InPromotion.facetCount = 0;
        }
        if (typeof facets.IsMigroskop.facetCount === 'undefined'){
            facets.IsMigroskop.facetCount = 0;
        }
        if (typeof facets.IsMCCProduct.facetCount === 'undefined'){
            facets.IsMCCProduct.facetCount = 0;
        }
        var filters = new Array();
        filters [0] = {k: "myFavorites", v: facets.CustomersFavourite.facetCount};
        filters [1] = {k: "myOldOrders", v: facets.CustomersPurchased.facetCount};
        filters [2] = {k: "inPromotion", v: facets.InPromotion.facetCount};
        filters [3] = {k: "migroskop", v: facets.IsMigroskop.facetCount};
        filters [4] = {k: "mcc", v: facets.IsMCCProduct.facetCount};

        var categories = [];
        
        for (var j=0;j<Math.min(facets.PathLevel2.length,filterResultLimit);j++){
            categories.push({"n": facets.PathLevel2[j].facetValue, c: facets.PathLevel2[j].facetCount});
        }
        filters[5] = {k:"categories",v:categories};

        var brands = [];
        for (var j=0;j<Math.min(facets.BrandName.length,filterResultLimit);j++){
            brands.push({"n": facets.BrandName[j].facetValue, c: facets.BrandName[j].facetCount});
        }
        filters[6] = {k:"brands",v:brands};

        var units = [];
        fillUnitFacetRanges(facets,units);
        filters[7] = {k:"units",v:units};

        var properties = [];
        for (var j=0;j<Math.min(facets.ProductProperty.length,filterResultLimit);j++){
            properties.push({"n": facets.ProductProperty[j].facetValue, c: facets.ProductProperty[j].facetCount});
        }
        filters[8] = {k:"productProperties",v:properties};

        migrosResp.filters = filters;
        
        //parse debug output
        var debugData = parseDebugExplain(solrdata);
        //Use PSI id instead of products
        //debugExplainResult[pid] = {"score":totalScore,"details":scoreArray};
        var debugDataPsi = {};
        for (var j = 0; j < solrDocs.length; j++) {
            var psi = docs[j]['PSIID'];
            var pid = docs[j]['ProductID'];
            debugDataPsi[psi] = {};
            debugDataPsi[psi] = debugData[pid];
            console.log (psi +" <- "+pid);
        }
        
       
        //migrosResp.debugData = debugData;
        migrosResp.debugData = debugDataPsi;
        
        return migrosResp;
    
};

/*
 * //Promotion
 /FunctionQuery.*product.*map.*termfreq.*InPromotion.*query.*ProductModelNameExact:/ -> product(map(and(termfreq(InPromotion_1005,true),exists($exactqq)),1,1,1,0),67108868)
 
 //Kampanya
 /FunctionQuery.*map.*query.*ProductID.*IsInCampaign:T/  -> FunctionQuery(map(exists(query(+(+ProductID:791714 +IsInCampaign:T)
 
 /FunctionQuery.*product.*map.*termfreq.*CustomersFavourite.*query.*ProductModelNameExact:/  -> product(map(and(termfreq(CustomersFavourite,737116),exists($exactqq)),1,1,1,0),4100)
 /FunctionQuery.*product.*map.*termfreq.*CustomersPurchased.*query.*ProductModelNameExact:/ -> product(map(and(termfreq(CustomersPurchased,737116),exists($exactqq)),1,1,1,0),4100)
 /FunctionQuery.*map.*query.*ProductModelNameExact:.*scale.*float.*SegAmount/ -> map(exists($exactqq),1,1,scale(field(SegAmount_null),1024,4092),0)
 /FunctionQuery.*map.*query.*ProductModelNameExact:.*scale.*float.*SegOrderCount/ -> map(exists($exactqq),1,1,scale(field(SegOrderCount_null),256,1020),0)
 /FunctionQuery.*map.*query.*ProductModelNameExact:.*scale.*float.*NumberOfClicks/ -> map(exists($exactqq),1,1,scale(field(NumberOfClicks),64,252),0)
 /FunctionQuery.*map.*query.*ProductModelNameExact:.*scale.*float.*Amount/ -> map(exists($exactqq),1,1,scale(field(Amount),16,60),0)
 /FunctionQuery.*map.*query.*ProductModelNameExact:.*scale.*float.*OrderCount/ -> map(exists($exactqq),1,1,scale(field(OrderCount),4,12),0),
 
 /FunctionQuery.*product.*map.*termfreq.*CustomersFavourite.*query.*ProductModelName:/  -> product(map(and(termfreq(CustomersFavourite,737116),exists($qq)),1,1,1,0),4100)
 /FunctionQuery.*product.*map.*termfreq.*CustomersPurchased.*query.*ProductModelName:/ -> product(map(and(termfreq(CustomersPurchased,737116),exists($qq)),1,1,1,0),4100)
 /FunctionQuery.*map.*query.*ProductModelName:.*scale.*float.*SegAmount/ -> map(exists($qq),1,1,scale(field(SegAmount_null),1024,4092),0)
 /FunctionQuery.*map.*query.*ProductModelName:.*scale.*float.*SegOrderCount/ -> map(exists($qq),1,1,scale(field(SegOrderCount_null),256,1020),0)
 /FunctionQuery.*map.*query.*ProductModelName:.*scale.*float.*NumberOfClicks/ -> map(exists($qq),1,1,scale(field(NumberOfClicks),64,252),0)
 /FunctionQuery.*map.*query.*ProductModelName:.*scale.*float.*Amount/ -> map(exists($qq),1,1,scale(field(Amount),16,60),0)
 /FunctionQuery.*map.*query.*ProductModelName:.*scale.*float.*OrderCount/ -> map(exists($qq),1,1,scale(field(OrderCount),4,12),0)
 * */
function parseDebugExplain (solrdata)
{
        var debugExplainResult = {};
        if (typeof solrdata["debug"] === 'undefined'){
            return debugExplainResult;
        }
        
        var debugExplain = solrdata["debug"]["explain"] ; 
        for (var pid in debugExplain){
            console.log ("Debug:"+pid);
            var scoreDetails = debugExplain[pid];
            var match = scoreDetails['match'];
            var totalScore = scoreDetails['value'];
            var funcScoreDetails = scoreDetails ['details'];
            var description = scoreDetails ['description'];
              
            /*console.log ("ProductID : "+pid);           
            console.log ("match = "+match);
            console.log ("Value = "+totalScore);
            console.log ("Description = "+description);
            */
            var scoreArray = []; 
            for (var fun in funcScoreDetails){
                var nextFun = funcScoreDetails[fun];
                var funMatch = nextFun['match'];
                var funTotalScore = nextFun['value'];
                var funcDesc = nextFun ['description'];
                
                //no need to return any partial score that is 0 or match = false
                if ((!funMatch) || funTotalScore === 0){
                    continue;
                }
                
                var selectedRanFuncName = funcDesc;
                
                //InPromotion
                if (funcDesc.match(/FunctionQuery.*product.*map.*termfreq.*InPromotion.*query.*ProductModelNameExact:/)){
                    selectedRanFuncName = "InPromotionExact";
                }
                //IsNEw
                if (funcDesc.match(/FunctionQuery.*product.*map.*termfreq.*IsNew.*query.*ProductModelNameExact:/)){
                    selectedRanFuncName = "IsNewExact";
                }
                //Kampanya
                else if (funcDesc.match(/FunctionQuery.*product.*map.*termfreq.*IsInCampaignCategory.*query.*ProductModelNameExact:/)){
                    selectedRanFuncName = "IsInCampaignCategoryExact";
                }
                else if (funcDesc.match(/FunctionQuery.*product.*map.*termfreq.*IsInCampaignBrand.*query.*ProductModelNameExact:/)){
                    selectedRanFuncName = "IsInCampaignBrandExact";
                }
                else if (funcDesc.match(/FunctionQuery.*product.*map.*termfreq.*IsInCampaign.*query.*ProductModelNameExact:/)){
                    selectedRanFuncName = "IsInCampaignExact";
                }
                
                else if (funcDesc.match(/FunctionQuery.*product.*map.*termfreq.*CustomersFavourite.*query.*ProductModelNameExact:/)){
                    selectedRanFuncName = "CustomersFavouriteExact";
                }
                else if (funcDesc.match(/FunctionQuery.*product.*map.*termfreq.*CustomersPurchased.*query.*ProductModelNameExact:/)){
                    selectedRanFuncName = "CustomersPurchasedExact";
                }
                else if (funcDesc.match(/FunctionQuery.*map.*query.*ProductModelNameExact:.*scale.*float.*SegAmount/)){
                    selectedRanFuncName = "SegAmountExact";
                }
                else if (funcDesc.match(/FunctionQuery.*map.*query.*ProductModelNameExact:.*scale.*float.*SegOrderCount/)){
                    selectedRanFuncName = "SegOrderCountExact";
                } 
                else if (funcDesc.match(/FunctionQuery.*map.*query.*ProductModelNameExact:.*scale.*int.*NumberOfClicks/)){
                    selectedRanFuncName = "NumberOfClicksExact";
                }
                else if (funcDesc.match(/FunctionQuery.*map.*query.*ProductModelNameExact:.*scale.*float.*Amount/)){
                    selectedRanFuncName = "AmountExact";
                }
                else if (funcDesc.match(/FunctionQuery.*map.*query.*ProductModelNameExact:.*scale.*int.*OrderCount/)){
                    selectedRanFuncName = "OrderCountExact";
                } 

                else if (funcDesc.match(/FunctionQuery.*product.*map.*termfreq.*CustomersFavourite.*query.*ProductModelName:/)){
                    selectedRanFuncName = "CustomersFavourite";
                } 
                else if (funcDesc.match(/FunctionQuery.*product.*map.*termfreq.*CustomersPurchased.*query.*ProductModelName:/)){
                    selectedRanFuncName = "CustomersPurchased";
                } 
                else if (funcDesc.match(/FunctionQuery.*map.*query.*ProductModelName:.*scale.*float.*SegAmount/)){
                    selectedRanFuncName = "SegAmount";
                }
                else if (funcDesc.match(/FunctionQuery.*map.*query.*ProductModelName:.*scale.*float.*SegOrderCount/)){
                    selectedRanFuncName = "SegOrderCount";
                }
                else if (funcDesc.match(/FunctionQuery.*map.*query.*ProductModelName:.*scale.*int.*NumberOfClicks/)){
                    selectedRanFuncName = "NumberOfClicks";
                } 
                else if (funcDesc.match(/FunctionQuery.*map.*query.*ProductModelName:.*scale.*float.*Amount/)){
                    selectedRanFuncName = "Amount";
                } 
                else if (funcDesc.match(/FunctionQuery.*map.*query.*ProductModelName:.*scale.*int.*OrderCount/)){
                    selectedRanFuncName = "OrderCount";
                }
                
                //InPromotion
                if (funcDesc.match(/FunctionQuery.*product.*map.*termfreq.*InPromotion.*query.*ProductModelName:/)){
                    selectedRanFuncName = "InPromotion";
                }
                //IsNew
                if (funcDesc.match(/FunctionQuery.*product.*map.*termfreq.*IsNew.*query.*ProductModelName:/)){
                    selectedRanFuncName = "IsNew";
                }
                //Kampanya
                else if (funcDesc.match(/FunctionQuery.*map.*query.*ProductID.*IsInCampaignCategory:T/)){
                    selectedRanFuncName = "IsInCampaignCategory";
                }
                else if (funcDesc.match(/FunctionQuery.*map.*query.*ProductID.*IsInCampaignBrand:T/)){
                    selectedRanFuncName = "IsInCampaignBrand";
                }
                else if (funcDesc.match(/FunctionQuery.*map.*query.*ProductID.*IsInCampaign:T/)){
                    selectedRanFuncName = "IsInCampaign";
                }
                
                
                //console.log ("Description Func="+selectedRanFuncName+" :"+funcDesc);
                scoreArray.push ({"score":funTotalScore,"rankFunc":selectedRanFuncName});
            }
            scoreArray = scoreArray.sort(function(a, b){
                return b.score-a.score;
             });
            debugExplainResult[pid] = {"score":totalScore,"details":scoreArray};
        }
        return debugExplainResult;
}
 
/*
         * "UnitVal_GR":{
        "counts":[
          "0.0",2,
          "100.0",4,
          "200.0",4,
          "300.0",1,
          "500.0",3,
          "600.0",1,
          "700.0",2,
          "800.0",2],
        "gap":100.0,
        "start":0.0,
        "end":2000.0},
         */
function fillUnitFacetRanges (facets,units)
{
    var faceList = facets['UnitExpr'];
    for (var x in faceList){
        /*
          "n": "7 - * ADET",
          "c": 10
        */
       var facetTriple = faceList[x];
       units.push({"n":facetTriple.facetValue, "c": facetTriple.facetCount});      
    }
};

function handlePostSolrRequest(inresponse, request) {
    
    console.log("Request handler 'handlePostSolrRequest' was called for " + request.url); 
    var body = '';
    request.on('data', function (data)
    {
        body += data;
    });
    request.on('end', function ()
    {
        console.log(body);  
        var postBody = JSON.parse(body);
        var sortkeyword = postBody['sortkeyword'];
        var solrURL = "";
        if (typeof sortkeyword !== 'undefined' && sortkeyword.length > 0){
            solrURL = rankingProcess.handleSortSolrRequest (postBody);
        }else
            solrURL = rankingProcess.handlePostSolrRequest (postBody);
       
        requestmod(solrURL, function (error, response, solrBody) {
            var reformattedResult = reformatSolrResult(solrBody,postBody);
            inresponse.writeHead(200, { 'Content-Type': 'application/json' });
            inresponse.write(JSON.stringify(reformattedResult));
            inresponse.end(); 
        }); 
    });
}


function start(response) {
    console.log("Request handler 'start' was called.");
    var page = fs.readFileSync(startpage, "utf8");

    response.writeHead(200, {"Content-Type": "text/html; charset=UTF-8"});
    response.write(page);
    response.end();
}

function css(response, request) {

    var filePath = '.' + request.pathname;
    if (filePath == './')
        filePath = './index.js';

    console.log("Request handler 'style' was called.");

    fs.readFile(filePath, function (error, file) {

        if (error) {

            response.writeHead(500, {"Content-Type": "text/plain"});

            response.write(error + "\n");

            response.end();

        } else {

            response.writeHead(200, {"Content-Type": "text/css"});

            response.write(file);

            response.end();

        }

    });

} 

exports.start = start;
exports.arabul = solrdata;
exports.solrdata = solrdata;
exports.handlePostSolrRequest=handlePostSolrRequest;
exports.css = css;
exports.test=test;

