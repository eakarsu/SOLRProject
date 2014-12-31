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
    var facetFieldsData = solrdata.facet_counts.facet_fields;
    for (var facetName in facetFieldsData){
        var facetQueryUrl = facetQueryUrlInit;
        
         var facetVals = facetFieldsData[facetName];
         var origFacetName = facetName;
         facetName = facetName.replace(/_.*/,"");
         //console.log("Facet name:"+origFacetName+":"+facetVals.length);
         /**
            "CustomersPurchased":[ "852708",4],
            "CustomersFavourite":[],
         */
        //Favori urunlerim veya eski siparislerim grubu
        var facetCount = 0;
        if (facetName.match(/CustomersFavourite|CustomersPurchased/)){
            if (facetVals.length === 1 ){
                facetCount = facetVals[1];
            }else{
                facetCount = 0;
            }
            facetQueryUrl = facetQueryUrl+ facetName+"="+customerid;
            facets[facetName] = {facetCount:facetCount,facetQueryUrl:facetQueryUrl};
        }
        //kampanyali urunler,migroskop urunleri veya money club indirimli urunler
        else if (facetName.match(/InPromotion|IsMigroskop|IsMCCProduct/)){
            facetCount = facetVals[3];
            if (facetName.match(/IsMigroskop/)){
                facetQueryUrl = facetQueryUrl+facetName+"=1";
            }else{
                facetQueryUrl = facetQueryUrl+facetName+"_"+storeid+"=true";
            }
            facets[facetName] = {facetCount:facetCount,facetQueryUrl:facetQueryUrl};
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
    console.log ("FACETS..");
    for (var prop in facets){
        var facetVal = facets [prop];
        console.log (prop+":"+facetVal.facetCount);
        if (facetVal.constructor === Array){
            for (var prop2 in facetVal){
                console.log (facetVal[prop2].facetValue+":"+facetVal[prop2].facetCount);
            }
        }
    }
    */
    return facets;
} 

function setupResults(body,storeid,custsegmentid,query) {
        
    var solrdata = JSON.parse(body);
    var docs = solrdata.response.docs;
    var numFound = solrdata.response.numFound;
    var start = solrdata.response.start;
    var highs = solrdata.highlighting;
    var responseHeader = solrdata.responseHeader;

    var rows = new Array();
    var flist = rankingProcess.getFL();
    
    var customerid = query.customerid;
    var facets = findFacetingValues(solrdata,customerid,storeid,query);
    
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
    
    var solrURL = rankingProcess.prepareBQOnlySOLRQuery2 (request);
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
            docs[j]['unit'] = row['UnitSymbol'];
            docs[j]['onStock'] = row['InStock'];
            docs[j]['inPromotion']= row['InPromotion'];
            docs[j]['myFavorites'] = row['myFavorites'];
            docs[j]['myOldOrders'] = row['myOldOrders'];
            docs[j]['migroskop'] = row['IsMigroskop'];
            docs[j]['mcc'] = row['IsMCCProduct'];
        } ;
        
        migrosResp.docs = docs;
        var facets = findFacetingValues(solrdata,customerid,storeid,{});

        var filters = new Array();
        filters [0] = {k: "myFavorites", v: facets.CustomersFavourite.facetCount};
        filters [1] = {k: "myOldOrders", v: facets.CustomersPurchased.facetCount};
        filters [2] = {k: "inPromotion", v: facets.InPromotion.facetCount};
        filters [3] = {k: "migroskop", v: facets.IsMigroskop.facetCount};
        filters [4] = {k: "mcc", v: facets.IsMCCProduct.facetCount};

        var categories = [];
        /*
        for (var prop in facets){
            var facetVal = facets [prop];
            console.log (prop+":"+facetVal.facetCount);
            if (facetVal.constructor === Array){
                for (var prop2 in facetVal){
                    console.log (facetVal[prop2].facetValue+":"+facetVal[prop2].facetCount);
                }
            }
        }
        */
    
    
        for (var j in facets.PathLevel2){
            categories.push({"n": facets.PathLevel2[j].facetValue, c: facets.PathLevel2[j].facetCount});
        }
        filters[5] = {k:"categories",v:categories};

        var brands = [];
        for (var j in facets.BrandName){
            brands.push({"n": facets.BrandName[j].facetValue, c: facets.BrandName[j].facetCount});
        }
        filters[6] = {k:"brands",v:brands};

        var units = [];
        for (var j in facets.UnitSymbol){
            units.push({"n": facets.UnitSymbol[j].facetValue, c: facets.UnitSymbol[j].facetCount});
        }
        filters[7] = {k:"units",v:units};

        var properties = [];
        for (var j in facets.ProductProperty){
            properties.push({"n": facets.ProductProperty[j].facetValue, c: facets.ProductProperty[j].facetCount});
         }
        filters[8] = {k:"productProperty",v:properties};

        migrosResp.filters = filters;
        return migrosResp;
    
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
        var solrURL = rankingProcess.handlePostSolrRequest (postBody);
       
        requestmod(solrURL, function (error, response, solrBody) {
            console.log ("SOLR response:"+solrBody);
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

