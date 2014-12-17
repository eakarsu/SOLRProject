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

function findFacetingValues (solrdata,query)
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
    var customerid = query.customerid;
    var storeid = query.storeid;
    var facets = {};
    var facetFieldsData = solrdata.facet_counts.facet_fields;
    for (var facetName in facetFieldsData){
        var facetQueryUrl = facetQueryUrlInit;
        console.log("Facet name:"+facetName);
         var facetVals = facetFieldsData[facetName];
         facetName = facetName.replace(/_.*/,"");
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
    
    facets = findFacetingValues(solrdata,query);
    
    for (j = 0; j < docs.length; j++) {
        rows[j] = {};
        for (k in flist){
            var field = flist[k];
            var newFieldName = field.replace(/SEGMENTID/g,custsegmentid).replace(/STOREID/g,storeid);
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
    
    var rData = {records: rows, nexturl: pgs.nexturl, prevurl: pgs.prevurl, pageindexes: pgs.pageindexes,
        startindex: pgs.startindex, endindex: pgs.endindex,
        qtime: results.qtime, numFound: results.numFound, queryString: query.q, currentindex: pgs.currentindex,
        customerid:query.customerid,storeid:query.storeid,custsegmentid:query.custsegmentid,discountlevel:query.discountlevel,solrURL:solrURLText,
        facets:pgs.facets};
  
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
exports.css = css;
exports.test=test;

