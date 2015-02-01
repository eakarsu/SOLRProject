
var router = require("./router");
var server = require("./server");
var path = require('path');

var requestHandlers = require("./requestHandlers");
var autosuggest = require("./autosuggestHandlers");
var autosuggestjson = require("./autosuggestHandlersJson");
var express = require('express');
var swig = require('swig');

var app = express();

app.use('/media', express.static(__dirname + '/media'));
app.use(express.static(__dirname + '/public'));

app.get('/', function(req,res) {
	requestHandlers.start(res);
});

app.get('/arabul', function(req,res) {
	requestHandlers.arabul(res,req);
});

app.get('/autosuggest', function(req,res) {
	autosuggest.autosuggest(res,req);
});
 
app.get('/autosuggestjson', function(req,res) {
	autosuggestjson.autosuggest(res,req);
});

app.post('/postsolrrequest', function(req,res) {
	requestHandlers.handlePostSolrRequest(res,req);
});


app.use(error);

function error(err, req, res, next) {
  // log it
  console.error(err.stack);

  requestHandlers.start(res);

  // respond with 500 "Internal Server Error".
  //res.send(500);
}


// Swig will cache templates for you, but you can disable
// that and use Express's caching instead, if you like:
app.set('view cache', false);
// To disable Swig's cache, do the following:
swig.setDefaults({ cache: false });

/*
var handle = {};
handle["/"] = requestHandlers.start;
handle["/start"] = requestHandlers.start;
handle["/upload"] = requestHandlers.upload;
handle["/show"] = requestHandlers.show;
handle["/solrdata"] = requestHandlers.solrdata;
handle["/arabul"] = requestHandlers.arabul;
handle["/css/"] = requestHandlers.css;

server.start(router.route, handle);
*/

app.listen(8888);
