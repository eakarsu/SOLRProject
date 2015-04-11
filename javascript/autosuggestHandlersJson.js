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
var mustache = require('mustache'); // bring in mustache template engine
var swig = require('swig');

var host = '192.168.191.143';
var port = '8080';

var basepath = "/arabul?";
var gradeWindowLen = 5; 
var reRankDocs = 5000;
var reRankWeight = 1000;
var maxCount = 5;
var rankingProcess = require("./rankingProcess");


function getSpellChecks (solrdata,topics)
{
    var spellcheck = solrdata.spellcheck.suggestions;
    console.log ("Spellcheck count :"+spellcheck.length);
    for (var j=2;j< spellcheck.length;j+=2){
       var word = spellcheck[j+1][1]; 
       console.log ("Spell check word="+word);
       var triple2 = {id:j,value:word}; 
       topics.push(triple2);
    }
};

function getSuggestTopics(response, body, query, requesturl,solrURL) {
    
    var customerid = query.customerid;
    var storeid = query.storeid;
    var custsegmentid = query.custsegmentid;
    var discountlevel = query.discountlevel;
    var showsolrreq = query.showsolrreq;
    
    var solrdata = JSON.parse(body);
    var highlighting = solrdata.highlighting;
    var docs = solrdata.response.docs;
    var numFound = solrdata.response.numFound;
    
    var psiIDProp = "PSIID_"+storeid;
    
    
    var counter = 0;
    var topics  = [];
    var pmnames = [];
    patternArray = [];
    var tries = 0;
    var j = -1;
    
    
	var docsPids ={};
    var nelems = Math.min(100,numFound);
    for (var j=0;j<nelems;j++ ){
        var pid = docs[j]['ProductID'];
        docsPids[j]= pid;
    };
	
    for (var docIndex in docsPids) {
        tries++;
        j++;
		var id = docsPids[docIndex];
        if (highlighting.hasOwnProperty(id)) {
            var origvalue = highlighting[id].suggest_ngram[0];
            var pattern = origvalue.match(/<em>[A-Za-z0-9çÇgGiIöÖsSüÜ]*<\/em>/g);
            if (pattern !== null){
                pattern = pattern.join(" ").replace(/<em>|<\/em>/g,"");
            }else{
                continue;
            }
            if (pattern !== null){
                var index = patternArray.indexOf(pattern);
                if (index < 0 && counter < maxCount){ 
                    if (typeof docs[docIndex][psiIDProp] === 'undefined'){
                        continue;
                    }
                    var pid = id;
                    var psi = docs[docIndex][psiIDProp]; 
                    
                    patternArray.push(pattern);
                    var triple2 = {psi:psi,value:pattern,pid:pid}; 
                    topics.push(triple2);
                    counter++;
					
					//add pmnames
					var value = origvalue.replace(/<em>|<\/em>/g,"");
					var shopCategoryId = docs[docIndex]['shopCategoryId']; 
					var shopCategoryName = docs[docIndex]['shopCategoryName']; 
					var shopCategoryNameEn = docs[docIndex]['shopCategoryNameEn']; 
					 
					var triple1 = {psi:psi,value:value,pid:pid,
						shopCategoryId:shopCategoryId,shopCategoryName:shopCategoryName,shopCategoryNameEn:shopCategoryNameEn}; 
					pmnames.push(triple1); 
				
                }
                if (counter === maxCount){
                    break;
                }
            }
        }
    }
    console.log("Tried count="+tries);
     
    if (counter === 0){
        getSpellChecks(solrdata,topics);
    }
     
    var words = [];
    for (var k in topics){
        words.push(topics[k].value);
    }
    
    var products = [];   
    for (var k in pmnames){
        var triple = {productId:pmnames[k].pid,name:pmnames[k].value,psi:pmnames[k].psi,
            shopCategoryId:pmnames[k].shopCategoryId,shopCategoryName:pmnames[k].shopCategoryName,shopCategoryNameEn:pmnames[k].shopCategoryNameEn};
        products.push(triple);
    }
    
    var tuple = {products:products,words:words};
    
    response.writeHead(200, { 'Content-Type': 'application/json;charset=utf-8' });
    response.write(JSON.stringify(tuple));
    response.end();
}; 

function autosuggest(presponse, request) {
    console.log("Request handler 'autosuggest' was called for " + request.url);
    var queryData = url.parse(request.url, true).query;
    var term = encodeURIComponent(queryData.term);
     
    var solrURL = rankingProcess.prepareSuggestQuery(request);
    solrURL = solrURL.replace(/autosuggest/,"autosuggestjson");
    
    console.log("Autosuggest url ext:"+solrURL);
       
    requestmod(solrURL, function (error, response, body) {
        getSuggestTopics(presponse, body, queryData, request.url,solrURL);

    });
}

exports.autosuggest = autosuggest;
