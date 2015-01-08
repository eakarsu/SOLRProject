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

var host = '192.168.191.141';
var port = '8080';

var basepath = "/arabul?";
var gradeWindowLen = 5; 
var reRankDocs = 5000;
var reRankWeight = 1000;
var maxCount = 5;
var rankingProcess = require("./rankingProcess");

function getSuggestTopics2(response, body, query, requesturl,solrURL) {
   
            
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

function getSpellChecks (solrdata,topics)
{
    var spellcheck = solrdata.spellcheck.suggestions;
    console.log ("Spellcheck count :"+spellcheck.length);
    for (var j=2;j< spellcheck.length;j+=2){
       var word = spellcheck[j+1][1]; 
       console.log ("Spell check word="+word);
       var triple2 = {id:j,value:word,label:word}; 
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
    var psiIDProp = "PSIID_"+storeid;
    
    var counter = 0;
    var topics  = [];
    var pmnames = [];
    patternArray = [];
    var tries = 0;
    var j = -1;
    for (var id in highlighting) {
        tries++;
        j++;
        if (highlighting.hasOwnProperty(id)) {
            var origvalue = highlighting[id].suggest_ngram[0];
            var pattern = origvalue.match(/<em>[A-Za-z0-9çÇğĞıİöÖşŞüÜ]*<\/em>/g);
            if (pattern !== null){
                pattern = pattern.join(" ").replace(/<em>|<\/em>/g,"");
            }else{
                continue;
            }
            if (pattern !== null){
                var index = patternArray.indexOf(pattern);
                if (index < 0 && counter < maxCount){ 
                    if (typeof docs[j][psiIDProp] === 'undefined'){
                        continue;
                    }
                    var psi = docs[j][psiIDProp]; 
                    patternArray.push(pattern);
                    var triple2 = {id:psi,value:pattern,label:pattern}; 
                    topics.push(triple2);
                    counter++;
                }
                if (counter === maxCount){
                    break;
                }
            }
        }
    }
    console.log("Tried count="+tries);
    
    counter = 0;
    j = 0;
     for (var id in highlighting) {
        j++;
        if (highlighting.hasOwnProperty(id)) {
            var origvalue = highlighting[id].suggest_ngram[0];
            var value = origvalue.replace(/<em>|<\/em>/g,"");
            var label  = origvalue.replace(/<em>/g,"<span class=\"hl_results\">");
            label = label.replace(/<\/em>/g,"</span>");
            if (counter < maxCount){ 
                var psi = docs[j][psiIDProp]; 
                var triple1 = {id:psi,value:value,label:label}; 
                pmnames.push(triple1); 
                counter++;
            }
            if (counter === maxCount){
                break;
            }
        }
    }
    
    if (counter === 0){
        getSpellChecks(solrdata,topics);
    }
    
    var triple = {id:id,value:value,label:"-------------------------------------"}; 
    pmnames.push(triple);
    pmnames = pmnames.concat(topics);
    
    response.writeHead(200, { 'Content-Type': 'application/json' });
    response.write(JSON.stringify(pmnames));
    response.end();
};

function autosuggest(presponse, request) {
    console.log("Request handler 'autosuggest' was called for " + request.url);
    var queryData = url.parse(request.url, true).query;
    var term = encodeURIComponent(queryData.term);
     
    var solrURL = rankingProcess.prepareSuggestQuery(request);
    console.log("Autosuggest url ext:"+solrURL);
       
    requestmod(solrURL, function (error, response, body) {
        getSuggestTopics(presponse, body, queryData, request.url,solrURL);

    });
}

exports.autosuggest = autosuggest;
