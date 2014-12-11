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

var host = 'localhost';
var port = '8080';
var solrpath = '/migrossolr/ProductsTRMorphFullProductionSuggest/suggest_topic?q=';
var basepath = "/arabul?";
var gradeWindowLen = 5; 
var reRankDocs = 5000;
var reRankWeight = 1000;
var maxCount = 5;

function getSuggestTopics(response, body, query, requesturl,solrURL) {
   
            
    var solrdata = JSON.parse(body);
    var highlighting = solrdata.highlighting;
   
    var counter = 0;
    var topics  = [];
    var pmnames = [];
    patternArray = [];
    for (var id in highlighting) {
        if (highlighting.hasOwnProperty(id)) {
            var origvalue = highlighting[id].suggest_ngram[0];
            var pattern = origvalue.match(/<em>[A-Za-z0-9çÇğĞıİöÖşŞüÜ]*<\/em>/g);
            if (pattern !== null){
                pattern = pattern.join(" ").replace(/<em>|<\/em>/g,"");
            }else{
                continue;
            }
            var value = origvalue.replace(/<em>|<\/em>/g,"");
            var label  = origvalue.replace(/<em>/g,"<span class=\"hl_results\">");
            label = label.replace(/<\/em>/g,"</span>");
            console.log(id+":"+origvalue+" value="+value+":"+label+": pattern="+pattern);
            if (pattern !== null){
                var index = patternArray.indexOf(pattern);
                if (index < 0 && counter < maxCount){ 
                    patternArray.push(pattern);
                    var triple1 = {id:id,value:value,label:label}; 
                    pmnames.push(triple1); 
                    var triple2 = {id:id+1,value:pattern,label:pattern}; 
                    topics.push(triple2);
                    counter++;
                }
                if (counter === maxCount){
                    break;
                }
            }
        }
    }
    var triple = {id:id,value:value,label:"-------------------------------------"}; 
    topics.push(triple); 
    topics = topics.concat(pmnames);
    
    response.writeHead(200, { 'Content-Type': 'application/json' });
    response.write(JSON.stringify(topics));
    response.end();
};

function autosuggest(presponse, request) {
    console.log("Request handler 'autosuggest' was called for " + request.url);
    var queryData = url.parse(request.url, true).query;
    var term = queryData.term;
     
    var solrURL = "http://" + host + ":" + port + solrpath+term;
    requestmod(solrURL, function (error, response, body) {
        getSuggestTopics(presponse, body, queryData, request.url,solrURL);

    });
}

exports.autosuggest = autosuggest;
