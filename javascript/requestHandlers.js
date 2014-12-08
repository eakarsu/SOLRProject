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
var pblock = 10;
var resultspage = "../resources/aramasonuclari.html";
var startpage = "../resources/index.html";

//The url we want is: 'www.random.org/integers/?num=1&min=1&max=10&col=1&base=10&format=plain&rnd=new'

var host = 'localhost';
var port = '8080';
var path = '/migrossolr/ProductsTRMorphTestIst/select?wt=json&indent=true';

function setupResults(body) {
    var solrdata = JSON.parse(body);
    var docs = solrdata.response.docs;
    var numFound = solrdata.response.numFound;
    var start = solrdata.response.start;
    var highs = solrdata.highlighting;
    var responseHeader = solrdata.responseHeader;


    var rows = new Array();
    for (j = 0; j < docs.length; j++) {
        var ProductID = docs[j].ProductID;
        var ProductModelID = docs[j].ProductModelID;
        var ProductModelName = docs[j].ProductModelName;
        var ShopCode = docs[j].ShopCode;
        var ShopID = docs[j].ShopID;
        var TotalSold = docs[j].TotalSold;
	var IsInCampaign = docs[j].IsInCampaign;
	var CustomerID = docs[j].CustomerID;
        var StoreID = docs[j].StoreID;
        var CategoryID = docs[j].CategoryID;
        var ProductMoreDetail = docs[j].ProductMoreDetail;
	var PromotionType = docs[j].PromotionType;
	var CategoryPath = docs[j].CategoryPath;
	var ProductPrice = docs[j].ProductPrice;
        var ProductFeatures = docs[j].ProductFeatures;
 
        ProductMoreDetail = ProductMoreDetail.replace(/\r\n|\n/g, '');
       
        rows[j] = {ProductID: ProductID,ProductModelID: ProductModelID, ProductModelName: ProductModelName,
            ShopCode: ShopCode, ShopID: ShopID, StoreID: StoreID,
            CategoryID: CategoryID, ProductMoreDetail: ProductMoreDetail,
		TotalSold:TotalSold,IsInCampaign:IsInCampaign,CustomerID:CustomerID,
		PromotionType:PromotionType,CategoryPath:CategoryPath,ProductPrice:ProductPrice,
                ProductFeatures:ProductFeatures};
    }  
    ;
    return {rows: rows, numFound: numFound, start: start, qtime: responseHeader.QTime};
}

function setupPagination(start, query, numFound, requesturl) {
    var nexturl = true, prevurl = true;
    var pages = new Array();
    var startindex = query.startindex, endindex = query.endindex;
     
    var promotion = query.promotion;
    var totalsold = query.totalsold;
    var customerid = query.customerid;
    var storeid = query.storeid;
    console.log ("promotion="+promotion+":"+totalsold+":"+customerid+":"+storeid+":"+query);
    if (promotion == 'undefined'){
        console.log ("campaing is not define: OFF");
    }
    
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
    var partialpath = basepath + queryparam;

    /*
     // replace start=229893 with empty string
     var regex=/start=[0-9]+/;
     var querywostart = requesturl.replace(regex,"");
     console.log ("querywostart="+querywostart);
     */

    var endblock = endindex * pblock;
    if (endblock <= numFound) {
        startindex = parseInt(startindex);
        endindex = parseInt(endindex);
        for (var j = startindex; j <= endindex; j++) {
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

function buildPage(response, body, query, requesturl) {
    var results = setupResults(body);
    var rows = results.rows;

    console.log("buildPage:numFound=" + results.numFound + " start=" + results.start);

    var pgs = setupPagination(results.start, query, results.numFound, requesturl);

    /*var rData = {records:rows,nexturls:false,prevurls:["prevurl1"],pageindexes:[{index:"1",url:"url1"},
     {index:"2",url:"url2"},{index:"3",url:"url3"}]}; // wrap the data in a global object... (mustache starts from an object then parses)
     */
    var rData = {records: rows, nexturl: pgs.nexturl, prevurl: pgs.prevurl, pageindexes: pgs.pageindexes,
        startindex: pgs.startindex, endindex: pgs.endindex,
        qtime: results.qtime, numFound: results.numFound, queryString: query.q, currentindex: pgs.currentindex,
        customerid:query.customerid,storeid:query.storeid,custsegmentid:query.custsegmentid,discountlevel:query.discountlevel};
 
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
    console.log("url=" + request.url + " q=" + queryData.q + " start=" + queryData.start + " options=" + host +
            ":" + path+" storeid="+queryData.storeid+" customerid="+queryData.customerid+" custsegmentid="+
            queryData.custsegmentid+" discountlevel="+queryData.discountlevel);


    var lpath = path + "&" + request.url.substring(basepath.length);
    var lurl = "http://" + host + ":" + port + lpath;
    console.log("Pulling solr data from " + lurl);

    requestmod(lurl, function (error, response, body) {
        buildPage(presponse, body, queryData, request.url);

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

