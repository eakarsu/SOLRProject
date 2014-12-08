/* 
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

var host = 'localhost';
var port = '8080';
var path = '/migrossolr/ProductsTRMorphTestIst/select?wt=json&indent=true';
var basepath = "/arabul?";

function prepareSOLRQuery(request)
{
  
    var query = url.parse(request.url, true).query;
    var startindex = query.startindex
    var endindex = query.endindex
    var queryKeyword = query.q
    var customerid = query.customerid
    var storeid = query.storeid
    var custsegmentid = query.custsegmentid
    var discountlevel = query.discountlevel
   
    console.log("url=" + request.url + " q=" + queryData.q + " storeid="+queryData.storeid+" customerid="+queryData.customerid+" custsegmentid="+
            queryData.custsegmentid+" discountlevel="+queryData.discountlevel);
 
            
    var lpath = path + "&" + request.url.substring(basepath.length);
    var lurl = "http://" + host + ":" + port + lpath;
};
