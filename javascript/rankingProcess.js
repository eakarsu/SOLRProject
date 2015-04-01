/*
 * bf=map(exists($exactqq),1,1,SegOrderCount_101,1)
 * exactqq={!edismax bf='' }ProductModelNameExact:havuç OR ProductModelName_TR:havuç&debug.explain.structured=true
 * 
 * @type type
 */

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
var nodeApp = require("./app.js");

var host = '195.87.93.139';
//var host = 'localhost';
var port = '8080';
var basepath = "/arabul?";
var gradeWindowLen = 5;
var reRankDocs = 5000;
var reRankWeight = 1000;
var campaignInfo = require("./campaignInfo");
var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];


//InPromotion_STOREID with rankling  4,7 or 9 will be inserted based on the discountPrefLev - discount prefrence level-kampanya duyarliligi 
//and all other adjusted

var rankOrder = {
    ProductModelNameExact: 1,
    ProductModelNameExact_TR: 1,
    ProductModelName: 2,
    ProductModelName_TR: 2,
    CustomersFavourite: 3,
    CustomersPurchased: 4,
    SegAmountGrade_SEGMENTID: 5,
    SegOrderCountGrade_SEGMENTID: 6,
    IsNew: 7,
    AmountGrade: 8,
    OrderCountGrade: 9,
    NumberOfClicksGrade: 10,
    IsInCampaign:11,
    IsInCampaignCategory:11,
    IsInCampaignBrand:11,
    BrandName: 12,
    BrandName_TR: 12,
    ProductFeatures: 12,
    ProductFeatures_TR: 12,
    Description: 12,
    Description_TR: 12,
    ProductProperty: 12,
    ProductProperty_TR: 12};

var flList = [
    'ProductID',
    'ProductModelID',
    'ProductModelName',
    'SegAmount_SEGMENTID',
    'SegOrderCount_SEGMENTID',
    'NumberOfClicks',
    'Amount',
    'OrderCount',
    'BrandName',
    'ProductFeatures',
    'ProductProperty',
    'PathLevel2',
    'IsMigroskop',
    'Price_STOREID',
    'InStock_STOREID',
    'PSIID_STOREID',
    'InPromotion_STOREID',
    'IsNew',
    'SearchKeyword',
    'score',
    'NumberOfAddCarts',
    'UnitVal_ADET',   
    'UnitVal_M', //"CM","MM"
    'UnitVal_KG', //"GR","G"
    'UnitVal_LT', //"L", "CC", "ML"
    'UnitVal_MP',
    'UnitVal_V',
    'UnitVal_WATT',
    'UnitVal_W',
    'IsInCampaign',
    'IsInCampaignCategory',
    'IsInCampaignBrand',
    'myFavorites:exists(query({!v="CustomersFavourite:CUSTOMERID"}))',
    'myOldOrders:exists(query({!v="CustomersPurchased:CUSTOMERID"}))'
];
  

var qlList = [
    'ProductModelNameExact',
    'ProductModelName',
    'BrandName',
    'ProductFeatures',
    'Description',
    'ProductProperty',
    'ProductModelName',
    'BrandName_TR',
    'ProductFeatures_TR',
    'Description_TR',
    'ProductProperty_TR'
];
   
var facetFields = [
    'IsMCCProduct_STOREID',
    'IsMigroskop',
    'InPromotion_STOREID',
    'InStock_STOREID',
    'Price_STOREID',
    'SegAmount_SEGMENTID',
    'SegOrderCount_SEGMENTID',
    'NumberOfClicks',
    'Amount',
    'OrderCount',
    'PathLevel2_Facet',
    'BrandName_Facet',
    'ProductProperty_Facet',
    'IsInCampaign'
];

 var facetQueries = [
     '{!ex=customer}exists(query({!v="CustomersFavourite:CUSTOMERID"}))',
     '{!ex=customer}exists(query({!v="CustomersPurchased:CUSTOMERID"}))'
 ];

 
//InPromotion_STOREID with rankling  4,7 or 9 will be inserted based on the discountPrefLev - discount prefrence level-kampanya duyarliligi 
//and all other adjusted

function getSolrPath ( type)
{
    //var d = new Date();
    //var n = d.getDay();
    //var coreName = "ProductsCore"+days[n];
    var coreName = nodeApp.getActiveCoreName ();
    var path = "";
    if (type === "Prod"){
        path  = '/migrossolr/'+coreName+'/myselect?';
    }else if (type === "Auto"){
        path  = '/migrossolr/'+coreName+'/suggest_topic?';
    }
    
    return path;
};

function getFL()
{
    return flList;
}

/*
 * 
 * @param {type} localRankOrder - create new rankign order object based on discount preference level
 * Make a copy of orginal one and insert  InPromotion_STOREID field and aadjust ranking levels of all fields
 * that has equa or gerater than inserted new field with ranking oreder disPrefRank
 * @param {type} disPrefRank - ranking order of InPromotion_STOREID field
 * @param {type} storeid - stoere id of product
 * @param {type} custsegmentid - custoemr segment id. Replace 2 fields with real correct one throuhg relacing SEGMENTID with this value
 * @returns {undefined} - new ranking order object
 */
function adjustRankOrder(localRankOrder, storeid, custsegmentid, discountPrefLev)
{
    var disPrefRank = -1;
    if (discountPrefLev === "1")
        disPrefRank = 4;
    else if (discountPrefLev === "2")
        disPrefRank = 7;
    else if (discountPrefLev === "3")
        disPrefRank = 9;

    for (var prop in localRankOrder) {
        var rankVal = localRankOrder[prop];
        var newPropName = prop;
        if (prop.indexOf("_SEGMENTID") >= 0 && ((typeof custsegmentid !== 'undefined') && custsegmentid !== "")) {
            newPropName = prop.replace("SEGMENTID", custsegmentid);
            localRankOrder[newPropName] = rankVal;
            delete localRankOrder[prop];
        }
        if (localRankOrder[newPropName] >= disPrefRank && disPrefRank !== -1)
            localRankOrder[newPropName] = rankVal + 1;
    }
    if (((typeof storeid !== 'undefined') && storeid !== "") && disPrefRank !== -1) {
        var inPromotion = "InPromotion_" + storeid;
        localRankOrder[inPromotion] = disPrefRank;
    }

    for (prop in localRankOrder) {
        console.log(" adjustRankOrder prop:" + prop + " =" + localRankOrder[prop]);
    }

}
;


function prepareReRankExpr(localRankOrder, gradeWindowLen, customerid, reRankDocs, reRankWeight)
{
    var rerankExprs = [];
    var step = 10 / gradeWindowLen;
    for (field in localRankOrder) {
        var rankVal = (12 - localRankOrder[field]) * 100;
        if (field.indexOf("Grade") >= 0) {
            /*  bq=NumberOfClicksGrade:[5 TO 7]^10  */
            for (j = 0; j < 10; j += step) {
                var stepRankVal = rankVal + j * 10;
                var low = j;
                var high = j + step;
                var stmt = field + ":" + "[" + low + " TO " + high + "]^" + stepRankVal;
                rerankExprs.push(stmt);
            }
        } else if (field.indexOf("InPromotion") >= 0) {
            var expr = field + ":true" + "^" + rankVal;
            rerankExprs.push(expr);
        }
        else if (field.indexOf("Customers") >= 0 && (customerid !== '')) {
            var expr = field + ":" + customerid + "^" + rankVal;
            rerankExprs.push(expr);
        }
    }
    var fullRerankExpr = "rq={!rerank reRankQuery=$rqq reRankDocs=" + reRankDocs + " reRankWeight=" + reRankWeight + "}";
    fullRerankExpr = fullRerankExpr + "&rqq=" + rerankExprs.join(" ");
    return fullRerankExpr;
}


function prepareFirstQuery(localRankOrder)
{
    var pfExprs = [];
    var qfExprs = [];
    for (field in localRankOrder) {
        var rankVal = (12 - localRankOrder[field]) * 100;
        if (!field.match(/Grade|InPromotion|Customers/g)) {
            var expr = field + "^" + rankVal;
            qfExprs.push(expr);
            pfExprs.push(expr);
        }
    }
    result = "pf=" + qfExprs.join(" ") + "&pf=" + pfExprs.join(" ");
    return result;
}

function prepareQueryExpressions(localRankOrder, gradeWindowLen, customerid)
{
    var bqExprs = [];
    var pfExprs = [];
    var qfExprs = [];
    var step = 10 / gradeWindowLen;
    for (field in localRankOrder) {
        var rankVal = (12 - localRankOrder[field]) * 100;
        if (field.indexOf("Grade") >= 0) {
            /*  bq=NumberOfClicksGrade:[5 TO 7]^10  */
            for (j = 0; j < 10; j += step) {
                var stepRankVal = rankVal + j * 10;
                var low = j;
                var high = j + step;
                var stmt = "bq=" + field + ":" + "[" + low + " TO " + high + "]^" + stepRankVal;
                bqExprs.push(stmt);
            }
        } else if (field.indexOf("InPromotion") >= 0) {
            var expr = "bq=" + field + ":true" + "^" + rankVal;
            bqExprs.push(expr);
        }
        else if (field.indexOf("Customers") >= 0) {
            var expr = field + ":" + customerid + "^" + rankVal;
            pfExprs.push(expr);
            qfExprs.push(expr);
        } else {
            var expr = field + "^" + rankVal;
            pfExprs.push(expr);
            qfExprs.push(expr);
        }
    }
    var allBQ = bqExprs.join("&");
    var allPF = "pf=" + pfExprs.join(" ");
    var allQF = "qf=" + qfExprs.join(" ");
    var result = allBQ + "&" + allPF + "&" + allQF;
    return result;
}

function preparePFQFQuery(localRankOrder)
{
    var pfExprs = [];
    var qfExprs = [];
    for (var field in localRankOrder) {
        var rankVal = (12 - localRankOrder[field]) * 1;
        if (field.match(/ProductModelName/)) {
            rankVal = rankVal * 100;
        }
        if (!field.match(/Grade|Customers|InPromotion/)) {
            var expr = field + "^" + rankVal;
            pfExprs.push(expr);
            qfExprs.push(expr);
        }
    }
    var allPF = "pf=" + pfExprs.join(" ");
    //var allQF = "qf="+qfExprs.join(" ");
    var allQF = "bq=" + qfExprs.join(" ");
    //var result = allPF+"&"+allQF;
    var result = allPF + "&" + allQF;
    return result;
}

function sortObject(obj) {
    var arr = [];
    for (var prop in obj) {
        if (obj.hasOwnProperty(prop)) {
            arr.push({
                'key': prop,
                'value': obj[prop]
            });
        }
    }
    arr.sort(function (a, b) {
        return a.value - b.value;
    });
    //arr.sort(function(a, b) { a.value.toLowerCase().localeCompare(b.value.toLowerCase()); }); //use this to sort as strings
    return arr; // returns array
}

function prepareSortExpression(localRankOrder, customerid, searchKeyword)
{
    /**
     * map(exists($qq),1,1,Amount,0) desc
     * qq={!edismax}(ProductModelName:"ÇİZİK ZEYTİN")
     * @type String|@exp;sortExpr@call;replace
     */
    /*
     * 
     * map(or (termfreq(ProductModelName,"tuz"),termfreq(ProductModelName_TR,"tuz")),1,1,Amount,0) desc
     * map(and(termfreq(InPromotion_1005,true), or(termfreq(ProductModelName,"tuz"),termfreq(ProductModelName_TR,"tuz"))),1,1,1,0) desc
     * map(and(termfreq(CustomersPurchased_1005,CUSTOMERID), or(termfreq(ProductModelName,"tuz"),termfreq(ProductModelName_TR,"tuz"))),1,1,1,0) desc
     */

    var sortExpr = "map(or (termfreq(ProductModelName,'KEYWORD'),termfreq(ProductModelName_TR,'KEYWORD')),1,1,FIELDNAME,0) desc";
    var sortExpr2 = "map(and(termfreq(FIELDNAME,FIELDVALUE), or(termfreq(ProductModelName,'KEYWORD'),termfreq(ProductModelName_TR,'KEYWORD'))),1,1,1,0) desc";

    searchKeyword = encodeURIComponent(searchKeyword);
    sortExpr = sortExpr.replace(/KEYWORD/g, searchKeyword);
    sortExpr2 = sortExpr2.replace(/KEYWORD/g, searchKeyword);

    var sortedRankOrder = sortObject(localRankOrder);

    var allSortExprs = [];
    for (var index in sortedRankOrder) {
        var field = sortedRankOrder[index].key;
        if (field.match(/Grade/)) {
            var newFieldName = field.replace("Grade", "");
            sortExprTemp = sortExpr.replace("FIELDNAME", newFieldName);
            allSortExprs.push(sortExprTemp);
        } else if (field.match(/InPromotion/)) {
            sortExprTemp = sortExpr2.replace("FIELDNAME", field);
            sortExprTemp = sortExprTemp.replace("FIELDVALUE", "true");
            allSortExprs.push(sortExprTemp);
        }
        else if (field.match(/Customers/) && ((typeof customerid !== 'undefined') && customerid !== "")) {
            sortExprTemp = sortExpr2.replace("FIELDNAME", field);
            sortExprTemp = sortExprTemp.replace("FIELDVALUE", customerid);
            allSortExprs.push(sortExprTemp);
        }
    }

    var result = "sort=" + allSortExprs.join(",");
    return result;
}

function prepareExceptionRanking(allSortExprs, sortedRankOrder, sortExpr, sortExpr2, customerid)
{
    for (var index in sortedRankOrder) {
        var field = sortedRankOrder[index].key;
        if (field.match(/Grade/)) {
            var newFieldName = field.replace("Grade", "");
            var sortExprTemp = sortExpr.replace("FIELDNAME", newFieldName);
            allSortExprs.push(sortExprTemp);
        } else if (field.match(/InPromotion/)) {
            var sortExprTemp = sortExpr2.replace("FIELDNAME", field);
            sortExprTemp = sortExprTemp.replace("FIELDVALUE", "true");
            allSortExprs.push(sortExprTemp);
        }
        else if (field.match(/Customers/) && ((typeof customerid !== 'undefined') && customerid !== "")) {
            var sortExprTemp = sortExpr2.replace("FIELDNAME", field);
            sortExprTemp = sortExprTemp.replace("FIELDVALUE", customerid);
            allSortExprs.push(sortExprTemp);
        }
    }
}
;

function prepareSortExpression2(localRankOrder, customerid, searchKeyword)
{
    /**
     * map(exists($qq),1,1,Amount,0) desc
     * qq={!edismax}(ProductModelName:"ÇİZİK ZEYTİN")
     * @type String|@exp;sortExpr@call;replace
     */
    /*
     * 
     * map(or (exists(ProductModelName,"tuz"),termfreq(ProductModelName_TR,"tuz")),1,1,Amount,0) desc
     * map(and(termfreq(InPromotion_1005,true), or(termfreq(ProductModelName,"tuz"),termfreq(ProductModelName_TR,"tuz"))),1,1,1,0) desc
     * map(and(termfreq(CustomersPurchased_1005,CUSTOMERID), or(termfreq(ProductModelName,"tuz"),termfreq(ProductModelName_TR,"tuz"))),1,1,1,0) desc
     */

    //var qq = "{!edismax}(ProductModelName:\"KEYWORD\" OR ProductModelName_TR:\"KEYWORD\")";
    var qq = "{!edismax}(ProductModelName:KEYWORD OR ProductModelName_TR:KEYWORD)";
    var exactqq = "{!edismax}(ProductModelNameExact:\"KEYWORD\" OR ProductModelName_TR:\"KEYWORD\")";
    var sortExpr = "map(exists($qq),1,1,FIELDNAME,0) desc";
    var sortExpr2 = "map(and(termfreq(FIELDNAME,FIELDVALUE),exists($qq)),1,1,1,0) desc";
    var exactSortExpr = "map(exists($exactqq),1,1,FIELDNAME,0) desc";
    var exactSortExpr2 = "map(and(termfreq(FIELDNAME,FIELDVALUE),exists($exactqq)),1,1,1,0) desc";

    searchKeywordEncoded = encodeURIComponent(searchKeyword);
    exactqq = exactqq.replace(/KEYWORD/g, searchKeywordEncoded);
    qq = qq.replace(/KEYWORD/g, searchKeywordEncoded);

    allSortExprs = [];
    var sortedRankOrder = sortObject(localRankOrder);

    prepareExceptionRanking(allSortExprs, sortedRankOrder, exactSortExpr, exactSortExpr2, customerid);
    prepareExceptionRanking(allSortExprs, sortedRankOrder, sortExpr, sortExpr2, customerid);

    qq = "qq=" + qq;
    exactqq = "exactqq=" + exactqq;
    var result = "sort=" + allSortExprs.join(",") + ",score desc&" + qq + "&" + exactqq;
    //var result = "sort="+allSortExprs.join(",")+"&"+exactqq;

    return result;
}

function getConstVal(index, sortedRankOrder, highestRank,multiplier)
{    
    var constVal = "1";
    for (var j = parseInt(index) + 1; j < sortedRankOrder.length; j++) {
        var field = sortedRankOrder[j].key;
        if (field.match(/Grade/)) {
            var localRankLevel = sortedRankOrder[j].value;
            constVal = Math.pow(4, (highestRank - localRankLevel + 1)) + multiplier;
            break; 
        }
    }
    return constVal;

}

function prepareExceptionRankingForBF(allSortExprs, sortedRankOrder, sortExpr, sortExpr2, customerid,multiplier,highestRank)
{
    var promConstVal = 0;
    for (var index in sortedRankOrder) {
        var field = sortedRankOrder[index].key;
        var rankLevel = sortedRankOrder[index].value;
        var rankVal = Math.pow(multiplier, (highestRank - rankLevel));
        var nextRankVal = Math.pow(multiplier, (highestRank - rankLevel + 1));
        promConstVal = Math.max(nextRankVal,promConstVal);
        
        //All numeric values here for all fields ending in "Grade". we need to scale the result to boost correctly
        if (field.match(/Grade/)) {
            var newFieldName = "scale(field(" + field.replace("Grade", "") + ")," + rankVal + "," + (nextRankVal - multiplier) + ")";
            var sortExprTemp = sortExpr.replace("FIELDNAME", newFieldName);
            sortExprTemp = sortExprTemp + rankVal;
            allSortExprs.push(sortExprTemp);
        } else if (field.match(/InPromotion|IsInCampaignCategory|IsInCampaignBrand|IsInCampaign|IsNew/)) {
            var constVal = getConstVal(index, sortedRankOrder, highestRank,multiplier);
            promConstVal = Math.max(constVal,promConstVal);
            
            var sortExprTemp = sortExpr2.replace("FIELDNAME", field).replace("CONST", constVal);
            sortExprTemp = sortExprTemp.replace("FIELDVALUE", "true");
            sortExprTemp = sortExprTemp + rankVal;
            allSortExprs.push(sortExprTemp);
        }
        else if (field.match(/Customers/) && ((typeof customerid !== 'undefined') && customerid !== "")) {
            var constVal = getConstVal(index, sortedRankOrder, highestRank,multiplier);
            promConstVal = Math.max(constVal,promConstVal);
            var sortExprTemp = sortExpr2.replace("FIELDNAME", field).replace("CONST", constVal);
            sortExprTemp = sortExprTemp.replace("FIELDVALUE", customerid);
            sortExprTemp = sortExprTemp + rankVal;
            allSortExprs.push(sortExprTemp);
        }
    }
    return multiplier*promConstVal;
}
;

function prepareBFExpression2(localRankOrder, customerid, searchKeyword)
{
    /*
     * bf=map(exists($exactqq),1,1,SegOrderCount_101,1)
     * exactqq={!edismax bf='' }ProductModelNameExact:havuç OR ProductModelName_TR:havuç&debug.explain.structured=true
     * 
     * @type type
     */

    var qq = "{!edismax bf=''}ProductModelName:KEYWORD OR ProductModelName_TR:KEYWORD OR SearchKeyword:KEYWORD";
    var exactqq = "{!edismax bf=''}ProductModelNameExact:\"KEYWORD\" OR ProductModelName_TR:\"KEYWORD\" OR SearchKeywordExact:\"KEYWORD\"";
    var sortExpr = "map(exists($qq),1,1,FIELDNAME,0)^";
    var sortExpr2 = "product(map(and(termfreq(FIELDNAME,FIELDVALUE),exists($qq)),1,1,1,0),CONST)^";
    var exactSortExpr = "map(exists($exactqq),1,1,FIELDNAME,0)^";
    var exactSortExpr2 = "product(map(and(termfreq(FIELDNAME,FIELDVALUE),exists($exactqq)),1,1,1,0),CONST)^";
    
    searchKeywordEncoded = encodeURIComponent(searchKeyword);
    exactqq = exactqq.replace(/KEYWORD/g, searchKeywordEncoded);
    qq = qq.replace(/KEYWORD/g, searchKeywordEncoded);
    
    allSortExprs = [];
    var sortedRankOrder = sortObject(localRankOrder);

    //debug
    /*for (var j = 0; j < sortedRankOrder.length; j++) {
        var field = sortedRankOrder[j].key;
        var localRankLevel = sortedRankOrder[j].value;
        console.log(field+":"+localRankLevel);
    }*/
    //debug
      
    var exactMatchMultiplier = campaignInfo.getExactMatchMultiplier ();
     
    var multiplier = 4;
    var highestRank =  sortedRankOrder[sortedRankOrder.length - 1].value;
    var promMaxRankVal = prepareExceptionRankingForBF(allSortExprs, sortedRankOrder, exactSortExpr, exactSortExpr2, customerid,multiplier,highestRank*exactMatchMultiplier ); // *2);
    prepareExceptionRankingForBF(allSortExprs, sortedRankOrder, sortExpr, sortExpr2, customerid,multiplier,highestRank);

    //Check keyword in campaign
    var campaignQueryInfo = campaignInfo.getCampaignData (multiplier,highestRank,promMaxRankVal,searchKeyword);
    var campExpr = campaignQueryInfo.campExpr;
    var campQuery = campaignQueryInfo.campQuery;
 
    if (campExpr.length > 0){
        campExpr = campExpr.join(" ")+" ";
        campQuery = "&"+campQuery.join("&");
    }
    
    qq = "qq=" + qq;
    exactqq = "exactqq=" + exactqq;
    //var result = "bf=" + campExpr+ allSortExprs.join(" ") + "&" + qq + "&" + exactqq;//+campQuery;
    var result = "bf=" + campExpr+ allSortExprs.join(" ") + "&" + qq + "&" + exactqq+campQuery;

    return result;
}

function prepareBFExpression2Suggest(localRankOrder, customerid, searchKeyword)
{
  
    var sortExpr = "FIELDNAME^";
    var sortExpr2 = "product(map(termfreq(FIELDNAME,FIELDVALUE),1,1,1,0),CONST)^";
 
    allSortExprs = [];
    var sortedRankOrder = sortObject(localRankOrder);

    var multiplier = 2;
    var highestRank =  sortedRankOrder[sortedRankOrder.length - 1].value;
    prepareExceptionRankingForBF(allSortExprs, sortedRankOrder, sortExpr, sortExpr2, customerid,multiplier,highestRank);

    var result = "bf=" + allSortExprs.join(" ");

    return result;
}


function prepareBQOnlyQuery2(localRankOrder, customerid, searchKeyword)
{
    /**
     * termfreq(text,'memory')
     * 
     * if(termfreq(turkishtext,'maydanoz'),Amount,42)^10
     * if(termfreq(ProductModelName,'maydanoz'),Amount,42)^10 if(termfreq(ProductModelNameExact,'maydanoz'),Amount,42)^10
     * if(or(termfreq(ProductModelName,'maydanoz'),termfreq(ProductModelNameExact,'maydanoz')),Amount,42)^10
     * @type Array
     * 
     * inqq="{!dismax qf=InPromotion_1005}true"
     * if(and(if(and(exists($inqq),or(termfreq(ProductModelName,'tuz'),termfreq(ProductModelNameExact,'tuz'),termfreq(ProductModelName_TR,'tuz'))),700,1),or(termfreq(ProductModelName,'tuz'),termfreq(ProductModelNameExact,'tuz'),termfreq(ProductModelName_TR,'tuz'))),700,1) 
     */
    var condExpr = "if(or(termfreq(ProductModelName,'KEYWORD'),termfreq(ProductModelNameExact,'KEYWORD'),termfreq(ProductModelName_TR,'KEYWORD')),RANKVAL,0)";
    //var condExpr2 = "if(and(exists(INQUERY),or(termfreq(ProductModelName,'KEYWORD'),termfreq(ProductModelNameExact,'KEYWORD'),termfreq(ProductModelName_TR,'KEYWORD'))),RANKVAL,0)";
    var condExpr2 = "if(and(termfreq(FIELD,'VALUE'),or(termfreq(ProductModelName,'KEYWORD'),termfreq(ProductModelNameExact,'KEYWORD'),termfreq(ProductModelName_TR,'KEYWORD'))),RANKVAL,0)";

    condExpr = condExpr.replace(/KEYWORD/g, searchKeyword);
    condExpr2 = condExpr2.replace(/KEYWORD/g, searchKeyword);

    var inqq = [];
    var bfExprs = [];
    for (var field in localRankOrder) {
        var rankVal = (12 - localRankOrder[field]) * 100;
        condExprTemp = condExpr.replace("RANKVAL", rankVal);
        condExprTemp2 = condExpr2.replace("RANKVAL", rankVal);
        if (field.match(/Grade/)) {
            field = field.replace("Grade", "") + "^" + rankVal;
            bfExprs.push(condExprTemp);
        } else if (field.match(/InPromotion/)) {
            //condExprTemp2 = condExprTemp2.replace("INQUERY","$inpromqq");
            condExprTemp2 = condExprTemp2.replace("FIELD", field);
            condExprTemp2 = condExprTemp2.replace("VALUE", "true");
            //condExprTemp2 = condExprTemp2+"^"+rankVal;
            bfExprs.push(condExprTemp2);
            //inqq.push("inpromqq=\"{!dismax query("+field+":true"+")}\"");
            //inqq.push("inpromqq=\"{!dismax qf="+field+"}true\"");
        }
        else if (field.match(/Customers/) && (typeof start !== 'undefined')) {
            //condExprTemp2 = condExprTemp2.replace("INQUERY","$incustqq");
            condExprTemp2 = condExprTemp2.replace("FIELD", field);
            condExprTemp2 = condExprTemp2.replace("VALUE", customerid);
            //condExprTemp2 = condExprTemp2+"^"+rankVal;
            bfExprs.push(condExprTemp2);
            //inqq.push("incustqq=\"{!dismax qf="+field+"}"+customerid+"\"");
        }
    }

    var result = "bf=" + bfExprs.join(" ");//+"&"+inqq.join("&");
    return result;
}



function prepareBQOnlyQuery(localRankOrder, customerid)
{
    var bfExprs = [];
    for (field in localRankOrder) {
        var rankVal = (12 - localRankOrder[field]) * 100;
        if (field.match(/Grade/)) {
            var expr = field + "^" + rankVal;
            bfExprs.push(expr);
        } else if (field.match(/InPromotion/)) {
            var expr = field + ":true" + "^" + rankVal;
            bfExprs.push(expr);
        }
        else if (field.match(/Customers/) && (typeof start !== 'undefined')) {
            var expr = field + ":" + customerid + "^" + rankVal;
            bfExprs.push(expr);
        }
    }
    var result = "bq=" + bfExprs.join(" ");
    return result;
}

function formQLParam(queryKeyword)
{
    var localQL = [];
    for (var f in qlList) {
        localQL.push(qlList[f] + ":" + queryKeyword);
    }
    var result = localQL.join(" OR ");
    return "(" + result + ")";
}

/**
 * StoreID = 2185
 * CustomersPurchased:127066 AND Kurabiye
 * custsegmentid=107
 * prepareSOLRQuery2(127066,2185,2,107,5,"kurabiye")
 
 * @param {type} customerid
 * @param {type} storeid
 * @param {type} discountPrefLev
 * @param {type} custsegmentid
 * @param {type} gradeWindowLen
 * @returns {String}
 */
function prepareSOLRQueryExt(customerid, storeid, discountPrefLev, custsegmentid, gradeWindowLen, queryKeyword, start)
{
    //InPromotion_STOREID will 4,7 or 9 based on the discountPrefLev - discount prefrence level-kampanya duyarliligi 
    //and all other adjusted  
    var localRankOrder = {};
    for (var prop in rankOrder) {
        localRankOrder[prop] = rankOrder[prop];
    }

    adjustRankOrder(localRankOrder, storeid, custsegmentid, discountPrefLev);

    /*
     * q=StoreID:2566 AND KAĞIT &fl=InPromotion_2566,Description,SearchKeywordValue,ProductModelName,
     * ProductMoreDetail,NumberOfClicksGrade,AmountGrade&wt=json&indent=true&bq=NumberOfClicksGrade:[5 TO 7]^10&
     * bq=AmountGrade:[1 TO 3]^12&bq=InPromotion_2566:true&stopwords=true
     */
    //Add facet.field=IsMigroskop after we add it to indexinf process
    var faceFields = "facet=true&facet.limit=-1&facet.field=BrandName&facet.field=PathLevel2&facet.field=CustomersPurchased&facet.field=InPromotion_STOREID";
    faceFields = "&facet.field==SegAmount_SEGMENTID&facet.field=SegOrderCount_SEGMENTID&facet.field=NumberOfClicks&facet.field=Amount&facet.field=OrderCount";
    faceFields = faceFields.replace(/STOREID/g, storeid);
    faceFields = faceFields.replace(/SEGMENTID/g, custsegmentid);

    var queryExpr = prepareQueryExpressions(localRankOrder, gradeWindowLen, customerid);
    console.log("query expr=" + queryExpr);

    var qlParam = formQLParam(queryKeyword);

    var fl = flList.join(",").replace(/SEGMENTID/g, custsegmentid).replace(/STOREID/g, storeid);
    var extraOpts = "wt=json&indent=true&stopwords=true&start=" + start;
    var solrURL = "q=StoreID:" + storeid + " AND " + qlParam + "&fl=" + fl + "&" + queryExpr + "&" + extraOpts;
    //var solrURL = "q=StoreID:"+storeid+" AND turkishtext:"+queryKeyword+"&"+fl+"&"+queryExpr+"&"+extraOpts;
    solrURL = solrURL + "&" + faceFields;

    return solrURL;

}
;

function prepareReRankSOLRQueryExt(customerid, storeid, discountPrefLev, custsegmentid, gradeWindowLen, queryKeyword, start, reRankDocs, reRankWeight)
{
    //InPromotion_STOREID will 4,7 or 9 based on the discountPrefLev - discount prefrence level-kampanya duyarliligi 
    //and all other adjusted 
    var localRankOrder = {};
    for (var prop in rankOrder) {
        localRankOrder[prop] = rankOrder[prop];
    }

    adjustRankOrder(localRankOrder, storeid, custsegmentid, discountPrefLev);

    //Add facet.field=IsMigroskop after we add it to indexinf process
    var faceFields = "facet=true&facet.limit=-1&facet.field=BrandName&facet.field=PathLevel2&facet.field=CustomersPurchased&facet.field=InPromotion_STOREID";
    faceFields = faceFields.replace(/STOREID/g, storeid);

    var firstQuery = prepareFirstQuery(localRankOrder);
    var rerankQuery = prepareReRankExpr(localRankOrder, gradeWindowLen, customerid, reRankDocs, reRankWeight);

    var fl = flList.join(",").replace(/SEGMENTID/g, custsegmentid).replace(/STOREID/g, storeid);
    var extraOpts = "wt=json&indent=true&stopwords=true&start=" + start;
    var solrURL = "q=StoreID:" + storeid + " AND " + queryKeyword + "&fl=" + fl + "&" + firstQuery + "&" + rerankQuery + "&" + extraOpts;
    solrURL = solrURL + "&" + faceFields;

    return solrURL;

}
;
/* 
 * Create create with searching only on ProductModelName
 * and aad all other quesries on bf=
 * bf=OrderCountGrade^100 (and other *Grade attribites here)..InPromotion_^5 Customers*^5
 * @param {type} customerid
 * @param {type} storeid
 * @param {type} discountPrefLev
 * @param {type} custsegmentid
 * @param {type} gradeWindowLen
 * @param {type} queryKeyword
 * @param {type} start
 * @param {type} reRankDocs
 * @param {type} reRankWeight
 * @returns {String}
 */
function prepareOnlyBQOnlyQueryExt(customerid, storeid, discountPrefLev, custsegmentid, queryKeyword, start)
{
    //InPromotion_STOREID will 4,7 or 9 based on the discountPrefLev - discount prefrence level-kampanya duyarliligi 
    //and all other adjusted  
    var localRankOrder = {};
    for (var prop in rankOrder) {
        localRankOrder[prop] = rankOrder[prop];
    }

    adjustRankOrder(localRankOrder, storeid, custsegmentid, discountPrefLev);

    //Add facet.field=IsMigroskop after we add it to indexinf process
    var faceFields = "facet=true&facet.limit=-1&facet.field=BrandName&facet.field=PathLevel2&facet.field=CustomersPurchased&facet.field=InPromotion_STOREID";
    faceFields = faceFields.replace(/STOREID/g, storeid);

    var bqOnlyQuery = prepareBQOnlyQuery(localRankOrder, customerid);

    queryKeyword = encodeURIComponent(queryKeyword);
    var fl = "fl=" + flList.join(",").replace(/SEGMENTID/g, custsegmentid).replace(/STOREID/g, storeid);
    var extraOpts = "wt=json&indent=true&stopwords=true&start=" + start;
    var solrURL = "q=StoreID:" + storeid + " AND ProductModelName:" + queryKeyword + "&" + fl + "&" + bqOnlyQuery + "&" + extraOpts;
    solrURL = solrURL + "&" + faceFields;

    return solrURL;

}
;

function makeOneBooleanSet (bucket,resultFilterCondExpr)
{
    var bexpr = bucket.join(" OR ");
    if (bucket.length > 1){
        resultFilterCondExpr.push("("+bexpr+")");
    }else if (bucket.length === 1){
        resultFilterCondExpr.push(bexpr);
    }
    
};

function makeOneBooleanSetTag (bucket,resultFilterCondExpr,label,customerid,storeid)
{
    var bexpr = bucket.join(" OR ");
    if (bucket.length > 1){
        bexpr = "("+bexpr+")";
    }
    console.log ("label="+label+" bexpr="+bexpr);
    if (bexpr !== ""){
        bexpr = "fq={!tag="+label+"}"+bexpr;
        resultFilterCondExpr.push(bexpr);
        for (x in bucket){
            var prop = bucket[x].match(/.*:/g)[0];
            prop = prop.replace(":","");
            if (prop.match(/PathLevel2|BrandName|ProductProperty/)){
                prop = prop+"_Facet";
            }
            if (prop.match(/CustomersPurchased|CustomersFavourite|InPromotion|IsMCCProduct|IsMigroskop/)){
                var custAtts= ["InPromotion","IsMCCProduct","IsMigroskop"];
                for (var x in custAtts){
                    prop = custAtts[x];
                    if (prop !== "IsMigroskop"){
                        prop = prop +"_"+storeid;
                    }
                    var facetEx = "facet.field={!ex="+label+"}"+prop;
                    if (resultFilterCondExpr.indexOf(facetEx) < 0){
                        resultFilterCondExpr.push(facetEx);
                    }
                }
                continue;
            }
            var facetEx = "facet.field={!ex="+label+"}"+prop;
            console.log ("pusing new facet expression:"+facetEx);
            if (prop.match(/UnitVal_/)){
                console.log ("Skipping prop="+prop);
                continue;
                //No need to do anything here. All set up in solrconfig.xml
            } 
            
            if (resultFilterCondExpr.indexOf(facetEx) < 0){
                resultFilterCondExpr.push(facetEx);
            }
        }
    }
};

function makeFilterBooleanExprTagExclude (facetList,customerid,storeid)
{
    var resultFilterCondExpr = [];
    var custBucket = [];
    var catBucket = [];
    var brandBucket = [];
    var unitBucket = [];
    var propBucket = [];
    
    console.log("makeFilterBooleanExpr="+facetList);
    for (var prop in facetList){
        console.log("makeFilterBooleanExpr:prop:"+prop+":"+facetList[prop]);
        var facetVal = facetList[prop];
        if (facetVal.constructor === Array && prop === 'PathLevel2'){//categories
            console.log ("Adding to pathleve bucket");
            for (var inprop in facetVal){
                console.log("CATGORY="+facetVal[inprop]);
                catBucket.push(prop+":\""+encodeURIComponent(facetVal[inprop])+"\"");
            }
        }
        else if (facetVal.constructor === Array && prop === 'BrandName'){ //brands
            console.log ("Adding to brand bucket");
            for (var inprop in facetVal){
                brandBucket.push(prop+":\""+encodeURIComponent(facetVal[inprop])+"\"");
            }
        }
        /* parse each range expressin: lb - ub UNITID : eg:  "7 - * ADET"*/
        //else if (facetVal.constructor === Array && prop === 'UnitExpr'){//units
        else if ( prop === 'UnitExpr'){//units
            console.log ("Adding to unitexpr bucket");
            if (facetVal.constructor !== Array){
                facetVal = [facetVal];
            }
            for (var x in facetVal){
                if (facetVal[x][0] === '"'){
                    facetVal[x] = facetVal[x].substring(1,facetVal[x].length-1);
                }
                var words = facetVal[x].split(/ |-/);
                var lb = words [0];
                var ub = words [3];
                var unitSymbol = words[4];
                var rangeQuery = "["+lb+ " TO "+ub+"]";
                var localPropName = "UnitVal_"+unitSymbol;
                var rangeExpr = localPropName+":"+rangeQuery;
                console.log ("Added :range expression= "+rangeExpr);
                unitBucket.push(rangeExpr);
            }
        }
        else if (facetVal.constructor === Array && prop === 'ProductProperty'){//productProperties
            console.log ("Adding to property bucket");
            for (var inprop in facetVal){
                propBucket.push(prop+":\""+encodeURIComponent(facetVal[inprop])+"\"");
            }
        }
        //CustomersFavourite ve CustomersPurchased 
        else if (prop === 'myOldOrders' && facetVal){
            console.log ("Adding CustomersPurchased:"+customerid+" for myOldOrders");
            custBucket.push("CustomersPurchased:"+customerid);
        }
        else if (prop === 'myFavorites' && facetVal){
            console.log ("Adding CustomersFavourite:"+customerid+" for myFavorites");
            custBucket.push("CustomersFavourite:"+customerid);
        }
        else if (!prop.match(/myOldOrders|myFavorites/)){   
            console.log ("Adding to cust bucket");
            custBucket.push(prop+":"+encodeURIComponent(facetVal));
        }
    }
    
    makeOneBooleanSetTag(custBucket,resultFilterCondExpr,"customer",customerid,storeid);
    makeOneBooleanSetTag(catBucket,resultFilterCondExpr,"category",customerid,storeid);
    makeOneBooleanSetTag(brandBucket,resultFilterCondExpr,"brand",customerid,storeid);
    makeOneBooleanSetTag(unitBucket,resultFilterCondExpr,"unit",customerid,storeid);
    makeOneBooleanSetTag(propBucket,resultFilterCondExpr,"property",customerid,storeid);
    
    return resultFilterCondExpr;
    
};

/*
(myFavorites | myOldOrders | inPromotion | migroskop | mcc ) AND 
(categories[0] |  categories[1] | ....) AND
(brands[0] | brands[1] | .....) AND
(units[0] | units[1] | ...) AND
(productProperties[0] | productProperties[1] | .....)
 */
function makeFilterBooleanExpr (facetList,customerid)
{
    var resultFilterCondExpr = [];
    var custBucket = [];
    var catBucket = [];
    var brandBucket = [];
    var unitBucket = [];
    var propBucket = [];
    
    console.log("makeFilterBooleanExpr="+facetList);
    for (var prop in facetList){
        console.log("makeFilterBooleanExpr:prop:"+prop+":"+facetList[prop]);
        var facetVal = facetList[prop];
        if (facetVal.constructor === Array && prop === 'PathLevel2'){//categories
            for (var inprop in facetVal){
                console.log("CATGORY="+facetVal[inprop]);
                catBucket.push(prop+":\""+encodeURIComponent(facetVal[inprop])+"\"");
            }
        }
        else if (facetVal.constructor === Array && prop === 'BrandName'){ //brands
            console.log ("Adding to brand bucket");
            for (var inprop in facetVal){
                brandBucket.push(prop+":\""+encodeURIComponent(facetVal[inprop])+"\"");
            }
        }
        else if (facetVal.constructor === Array && prop === 'UnitExpr'){//units
            for (var x=0;x<facetVal.length;x+=3){
                var rangeQuery = "["+facetVal[x+1]+ " TO "+facetVal[x+2]+"]";
                var localPropName = "UnitVal_"+facetVal[x];
                var rangeExpr = localPropName+":"+rangeQuery;
                unitBucket.push(rangeExpr);
            }
        }
        else if (facetVal.constructor === Array && prop === 'ProductProperty'){//productProperties
            for (var inprop in facetVal){
                propBucket.push(prop+":\""+encodeURIComponent(facetVal[inprop])+"\"");
            }
        }
        //CustomersFavourite ve CustomersPurchased 
        else if (prop === 'myOldOrders' && facetVal){
            console.log ("Adding CustomersPurchased:"+customerid+" for myOldOrders");
            custBucket.push("CustomersPurchased:"+customerid);
        }
        else if (prop === 'myFavorites' && facetVal){
            console.log ("Adding CustomersFavourite:"+customerid+" for myFavorites");
            custBucket.push("CustomersFavourite:"+customerid);
        }
        else if (!prop.match(/myOldOrders|myFavorites/)){   
            console.log ("Adding to cust bucket");
            custBucket.push(prop+":"+encodeURIComponent(facetVal));
        }
    }
    
    makeOneBooleanSet(custBucket,resultFilterCondExpr);
    makeOneBooleanSet(catBucket,resultFilterCondExpr);
    makeOneBooleanSet(brandBucket,resultFilterCondExpr);
    makeOneBooleanSet(unitBucket,resultFilterCondExpr);
    makeOneBooleanSet(propBucket,resultFilterCondExpr);
    
    return resultFilterCondExpr;
    
};

function addFacetingFields (storeid,customerid,custsegmentid,otherFacets)
{ 
    var facetFieldsListAr = facetFields.slice();
    for (x in facetFieldsListAr){
        facetFieldsListAr[x] = facetFieldsListAr[x].replace(/CUSTOMERID/g,customerid).replace(/STOREID/,storeid).replace(/SEGMENTID/,custsegmentid);
    }
    
    for (x in otherFacets){
        var facet = otherFacets[x];
        if (facet.match(/^facet.field/)){
            facet = facet.match(/}.*$/g)[0].replace("}","");
            
            var index = facetFieldsListAr.indexOf(facet);
            if (index >= 0){
                facetFieldsListAr.splice(index,1);
                console.log(" removing facet :"+facet);
            }
        }
    }
     //Add facting fields
    var facetFieldsList = facetFieldsListAr.join("&facet.field=");
    var allFaceQueries = facetQueries.join("&facet.query=").replace(/CUSTOMERID/g,customerid);
    var faceConfs = "facet=true&facet.mincount=1&facet.limit=100&facet.sort=count";
    ;
    var faceFieldsLocal = faceConfs + "&facet.field=" + facetFieldsList;
    if ((typeof customerid !== 'undefined') && customerid !== ''){ 
       faceFieldsLocal = faceFieldsLocal +"&facet.query="+allFaceQueries;
    }

    faceFieldsLocal = faceFieldsLocal.replace(/STOREID/g, storeid);
    faceFieldsLocal = faceFieldsLocal.replace(/SEGMENTID/g, custsegmentid);
    return faceFieldsLocal;
};

function prepareOnlyBQOnlyQueryExt2(customerid, storeid, discountPrefLev, custsegmentid, queryKeyword, start,facetList)
{
    
    var coreSearchPhrase ='q={!type=dismax qf="ProductModelName SearchKeywordValue PathLevel2 ProductFeatures ProductProperty BrandName SearchKeyword text ProductModelNameExact" q.op=AND}KEYWORD';
    
   //var coreSearchPhrase = "ProductModelName:KEYWORD OR SearchKeywordValue:KEYWORD OR PathLevel2:KEYWORD OR ProductFeatures:KEYWORD OR ProductProperty:KEYWORD OR BrandName:KEYWORD OR text:KEYWORD OR ProductModelNameExact:KEYWORD";
   //var coreSearchPhrase = "turkishtext:KEYWORD OR text:KEYWORD  OR ProductModelNameExact:KEYWORD";
   //calculate facet boolean expression
    //var fPair = makeFilterBooleanExpr() (facetList,customerid);
    var fPair = makeFilterBooleanExprTagExclude(facetList,customerid,storeid);
   
    var hlPars = "hl=true&hl.fl=ProductModelName&hl.encoder=html&hl.simple.pre=<b>&hl.simple.post=</b>&f.ProductModelName.hl.fragsize=30&f.ProductModelName.hl.snippets=3&f.ProductModelName.hl.alternateField=ProductModelName";
    // 
    //
    //InPromotion_STOREID will 4,7 or 9 based on the discountPrefLev - discount prefrence level-kampanya duyarliligi 
    //and all other adjusted  
    var localRankOrder = {};
    for (var prop in rankOrder) {
        localRankOrder[prop] = rankOrder[prop];
    }

    adjustRankOrder(localRankOrder, storeid, custsegmentid, discountPrefLev);

    //Add facting fields
    var faceFields = addFacetingFields (storeid,customerid,custsegmentid,fPair);

    //debuggin bf parameters for now with boosting instead of sorting */
    //var sortQuery = prepareSortExpression2(localRankOrder,customerid,queryKeyword);
    var sortQuery = prepareBFExpression2(localRankOrder, customerid, queryKeyword);

    var pfqfOnlyQuery = preparePFQFQuery(localRankOrder);
  
    var localFlList = [];
    for (var x in flList){
            localFlList.push(flList[x]);
    }
    if ((typeof customerid === 'undefined') || customerid === ''){        
        localFlList.splice(localFlList.length-2,2);
    }
    queryKeyword = encodeURIComponent(queryKeyword);
    coreSearchPhrase = coreSearchPhrase.replace (/KEYWORD/g,queryKeyword);
    var fl = "fl=" + localFlList.join(",").replace(/SEGMENTID/g, custsegmentid).replace(/STOREID/g, storeid).replace(/CUSTOMERID/g,customerid) + ",score";
    var extraOpts = "wt=json&indent=true&stopwords=true&start=" + start;
    var solrURL = "fq=StoreID:" + storeid + "&" + coreSearchPhrase +"&" + fl + "&" + sortQuery +  "&" + extraOpts;
    solrURL = solrURL + "&" + faceFields + "&" + hlPars;
    if (fPair.length > 0){
        solrURL = solrURL + "&"+fPair.join("&");
    }

    return solrURL;

};

function prepareSuggestQueryExt(customerid, storeid, discountPrefLev, custsegmentid, queryKeyword)
{
    var localRankOrder = {};
    for (var prop in rankOrder) {
        localRankOrder[prop] = rankOrder[prop];
    }

    adjustRankOrder(localRankOrder, storeid, custsegmentid, discountPrefLev);

    //debuggin bf parameters for now with boosting instead of sorting */
    //var sortQuery = prepareSortExpression2(localRankOrder,customerid,queryKeyword);
    var sortQuery = prepareBFExpression2Suggest(localRankOrder, customerid, queryKeyword);
 
    queryKeyword = encodeURIComponent(queryKeyword);
    var solrURL = "q=" + queryKeyword+"&fq=StoreID:"+storeid+"&" + sortQuery+"&fl=PSIID_"+storeid+",ProductID,shopCategoryId,shopCategoryName,shopCategoryNameEn";

    return solrURL;

};  

function prepareBrowseQuery(query)
{
    var queryKeyword = query.q;
    var customerid = query.customerid;
    var storeid = query.storeid;
    var custsegmentid = query.custsegmentid;
    var discountlevel = query.discountlevel;
    var showsolrreq = query.showsolrreq;
    
    var debugOpts = "";
    if (typeof debug !== 'showsolrreq' && showsolrreq == 'on'){
        debugOpts = "&showsolrreq=on"; 
    }
    
    /* q=kurabiye&startindex=0&endindex=10&customerid=127066&storeid=2185&discountlevel=1&custsegmentid=107&start=10 */
    var browseURL = basepath + "q=" + queryKeyword + "&customerid=" + customerid + "&storeid=" + storeid + "&discountlevel=" +
            discountlevel + "&custsegmentid=" + custsegmentid + debugOpts+"&";
    return browseURL;
}

function prepareSOLRQuery(request)
{

    var query = url.parse(request.url, true).query;
    var start = query.start;
    var queryKeyword = query.q;
    var customerid = query.customerid;
    var storeid = query.storeid;
    var custsegmentid = query.custsegmentid;
    var discountlevel = query.discountlevel;

    console.log("Received URL parameters from url=" + request.url + " q=" + queryKeyword +
            " storeid=" + storeid + " customerid=" + customerid + " custsegmentid=" +
            custsegmentid + " discountlevel=" + discountlevel + " start=" + start);

    if (typeof start === 'undefined') {
        start = 0;
        console.log("setting start to 0");
    }

    var solrQuery = prepareSOLRQueryExt(customerid, storeid, discountlevel, custsegmentid, gradeWindowLen, queryKeyword, start);
    var solrURL = "http://" + host + ":" + port + getSolrPath("Prod") + solrQuery;
    console.log("Sending solrURL=" + solrURL);
    return solrURL;
}
;

function prepareReRankSOLRQuery(request)
{

    var query = url.parse(request.url, true).query;
    var start = query.start;
    var queryKeyword = query.q;
    var customerid = query.customerid;
    var storeid = query.storeid;
    var custsegmentid = query.custsegmentid;
    var discountlevel = query.discountlevel;

    console.log("Received URL parameters from url=" + request.url + " q=" + queryKeyword +
            " storeid=" + storeid + " customerid=" + customerid + " custsegmentid=" +
            custsegmentid + " discountlevel=" + discountlevel + " start=" + start);

    if (typeof start === 'undefined') {
        start = 0;
        console.log("setting start to 0");
    }

    var solrQuery = prepareReRankSOLRQueryExt(customerid, storeid, discountlevel, custsegmentid, gradeWindowLen, queryKeyword, start, reRankDocs, reRankWeight);
    var solrURL = "http://" + host + ":" + port + getSolrPath("Prod") + solrQuery;
    console.log("Sending solrURL=" + solrURL);
    return solrURL;
}
;

function prepareBQOnlySOLRQuery(request)
{

    var query = url.parse(request.url, true).query;
    var start = query.start;
    var queryKeyword = query.q;
    var customerid = query.customerid;
    var storeid = query.storeid;
    var custsegmentid = query.custsegmentid;
    var discountlevel = query.discountlevel;

    console.log("Received URL parameters from url=" + request.url + " q=" + queryKeyword +
            " storeid=" + storeid + " customerid=" + customerid + " custsegmentid=" +
            custsegmentid + " discountlevel=" + discountlevel + " start=" + start);

    if (typeof start === 'undefined') {
        start = 0;
        console.log("setting start to 0");
    }

    var solrQuery = prepareOnlyBQOnlyQueryExt(customerid, storeid, discountlevel, custsegmentid, queryKeyword, start);
    var solrURL = "http://" + host + ":" + port + getSolrPath("Prod") + solrQuery;
    console.log("Sending solrURL=" + solrURL);
    return solrURL;
}
;

function insertEditDistance(queryKeyword)
{
    ////5 karaktere kadar 1, 10'a kadar 2, daha sonrasi icin 3 yapsak
    var slen = queryKeyword.length;
    var wordlist = queryKeyword.match(/([A-Za-z])+/g);
    var editDist = 0;
    if (slen <= 5) {
        editDist = 1;
    } else if (slen <= 10) {
        editDist = 2;
    } else {
        editDist = 3;
    }
    for (k in wordlist) {
        var word = wordlist[k];
        console.log("inspecting " + word);
        queryKeyword = queryKeyword.replace(word, word + "~" + editDist);
        console.log("inspecting qw" + queryKeyword);
    }
    return queryKeyword;
}
;


/*
 * 'IsMCCProduct_STOREID', //Money Club indirimli urunler
 'UnitSymbol', //Birim
 'IsMigroskop', //Migroskop urunler
 'BrandName', //Markalar
 'PathLevel2', //Reyonlar
 'CustomersPurchased', //eski siparislerim
 'CustomersFavourite', //Favoro urunlerim
 'InPromotion_STOREID' //kampanyali urunler
 */
function getFacetQueryParam(query)
{
    var facetQuery = "";
    var facetVal = "";
    var storeid = query.storeid;
    var isMcc = "IsMCCProduct_" + storeid;
    var isProm = "InPromotion_" + storeid;
    var facetList = {};
    for (var prop in query){
        console.log ("checking prop="+prop+":"+query[prop]);      
        if (prop.match(/PathLevel2|ProductProperty/)) {
            facetVal = query[prop];
            facetList[prop] = [];
            if (facetVal.constructor === Array){
                for (var index in facetVal){
                    var val = facetVal[index].replace(/"/g,"");
                    facetList[prop].push('"'+val+'"');
                  }
            } 
            else
             facetList[prop] = facetVal;
        }else if (prop === isMcc || prop === isProm || prop.match(/UnitExpr|IsMigroskop|BrandName|CustomersPurchased|CustomersFavourite|ProductProperty/)){
            facetVal = query[prop];
            facetList[prop] = facetVal;
        }
    }
    for (var prop in facetList){
        console.log ("facet prop="+prop+":"+facetList[prop]);
    }
    
    return facetList;
};

/**
 * 
 * @param {type} query
 * @returns {String|getPostedFacetQueryParam.query}
 * "filters": [
        {"k": "myFavorites", "v": true},
        {"k": "myOldOrders", "v": true},
        {"k": "inPromotion", "v": true},
        {"k": "migroskop", "v": true},
        {"k": "mcc", "v": true},
        {"k": "categories", "v": ["hazır çocuk yemekleri", "bibe
        ronlar"]},
        {"k": "brands", "v": ["milupa", "bebelac"]},
        {"k": "units", "v": ["kg","gr"]},
        {"k": "units", "v": ["UnitVal_ADET:[0 TO 100]", "UnitVal_ADET:[100 TO 200]"]}, //RESULT:new way of unit faceting
        {"k": "productProperty", "v": ["?", "?", "?"]}
    ]
{
  "keyword" : "ceviz",
  "store" : 237,
  "customerId" : 737116,
  "customerSegment" : null,
  "campaignSensitivity" : null,
  "offset" : 0,
  "limit" : 20,
  "filterResultLimit" : 10,
  "language" : "tr",
  "sortkeyword" : "",
   "filters" : [ {
    "k" : "units",
    "v" : ["ADET",1,200, "ADET",200,300]
  } ]
 
}

 */
function getPostedFacetQueryParam(postBody)
{
    
    var storeid = postBody["store"];
    var isMcc = "IsMCCProduct_" + storeid;
    var isProm = "InPromotion_" + storeid;
    var facetList = {};
    var filters = postBody["filters"];
    for (var j in filters){
        console.log ("Adding facet expr:"+filters[j]["v"]+":"+filters[j]["v"].length);
        if (filters[j]["k"] === "mcc") {
            facetList[isMcc] = filters[j]["v"];;
        }else if (filters[j]["k"] === "units") {
            facetList['UnitExpr'] =  filters[j]["v"];;
        }else  if (filters[j]["k"] === "migroskop") {
            console.log ("getPostedFacetQueryParam:migroskop:"+filters[j]["v"]);
            facetList['IsMigroskop'] = filters[j]["v"];
            console.log ("getPostedFacetQueryParam:migroskop:"+facetList['IsMigroskop']);
        }else  if (filters[j]["k"] === "brands") {
            facetList['BrandName'] = filters[j]["v"];
        }else  if (filters[j]["k"] === "categories") {
            facetList['PathLevel2'] = filters[j]["v"];
        }else  if (filters[j]["k"] === "myOldOrders") {
            facetList['myOldOrders'] = filters[j]["v"];         
        }else  if (filters[j]["k"] === "myFavorites") {
            facetList['myFavorites'] = filters[j]["v"];
        } else if (filters[j]["k"] === "inPromotion") {
            facetList[isProm] = filters[j]["v"];
        }else  if (filters[j]["k"] === "productProperties") {
            facetList['ProductProperty'] = filters[j]["v"];
        }
    };
    console.log ("facet list:"+facetList);
    
    return facetList;
};

function prepareBQOnlySOLRQuery2(request)
{

    var query = url.parse(request.url, true).query;
    var start = query.start;
    var queryKeyword = query.q;
    var customerid = query.customerid;
    var storeid = query.storeid;
    var custsegmentid = query.custsegmentid;
    var discountlevel = query.discountlevel;
    var showsolrreq = query.showsolrreq;
    
    var facetQueryPair = getFacetQueryParam(query);
    
    console.log("Received URL parameters from url=" + request.url + " q=" + queryKeyword +
            " storeid=" + storeid + " customerid=" + customerid + " custsegmentid=" +
            custsegmentid + " discountlevel=" + discountlevel + " start=" + start + " showsolrreq=" + showsolrreq);

    if (typeof start === 'undefined') {
        start = 0;
        console.log("setting start to 0");
    }

    var debugOpts = "";
    if (typeof debug !== 'showsolrreq' && showsolrreq == 'on'){
        debugOpts = "&indent=true&debugQuery=true&debug.explain.structured=true"; 
    }
    
    var solrQuery = prepareOnlyBQOnlyQueryExt2(customerid, storeid, discountlevel, custsegmentid, queryKeyword, start,facetQueryPair);
    var solrURL = "http://" + host + ":" + port + getSolrPath("Prod") + solrQuery+debugOpts;
    console.log("Sending solrURL=" + solrURL);
    return solrURL;
};

function prepareSuggestQuery(request)
{
 
    var query = url.parse(request.url, true).query;
    var start = query.start;
    var queryKeyword = query.q;
    var customerid = query.customerid;
    var storeid = query.storeid;
    var custsegmentid = query.custsegmentid;
    var discountlevel = query.discountlevel;
    var showsolrreq = query.showsolrreq;
    
    console.log("prepareSuggestQuery:Received URL parameters from url=" + request.url + " q=" + queryKeyword +
            " storeid=" + storeid + " customerid=" + customerid + " custsegmentid=" +
            custsegmentid + " discountlevel=" + discountlevel + " start=" + start + " showsolrreq=" + showsolrreq);

    if (typeof start === 'undefined') {
        start = 0;
        console.log("setting start to 0");
    }

    var solrQuery = prepareSuggestQueryExt(customerid, storeid, discountlevel, custsegmentid, queryKeyword);
    var solrURL = "http://" + host + ":" + port + getSolrPath("Auto") + solrQuery;
    console.log("Sending solrURL=" + solrURL);
    return solrURL;
};


/*
 * {
    "keyword": "elma",
    "store": 237,
    "customerId": 4380562,
    "campaignSensitivity": 1,
    "customerSegment": 101,
    "offset": 50,
    "limit": 100,
    "filterResultLimit": 5,
    "language": "tr",
	"filters": [
        {"k": "myFavorites", "v": true},
        {"k": "myOldOrders", "v": true},
        {"k": "inPromotion", "v": true},
        {"k": "migroskop", "v": true},
        {"k": "mcc", "v": true},
        {"k": "categories", "v": ["hazır çocuk yemekleri", "biberonlar"]},
        {"k": "brands", "v": ["milupa", "bebelac"]},
        {"k": "units", "v": ["kg", "gr"]},
        {"k": "productProperty", "v": ["?", "?", "?"]}
    ]
};
 */
function handlePostSolrRequest(postBody)
{

    var queryKeyword = postBody["keyword"];
    var customerid = postBody["customerId"];
    var storeid = postBody["store"];
    var custsegmentid = postBody["customerSegment"];
    var discountlevel = postBody["campaignSensitivity"];
    var debug = postBody["debug"];
    var showsolrreq = false;

    var debugOpts = "";
    if (typeof debug !== 'undefined' && debug){
        debugOpts = "&indent=true&debugQuery=true&debug.explain.structured=true"; 
    }
    var facetQueryPair = getPostedFacetQueryParam(postBody);
    var start = postBody['offset'];
    var rows = postBody['limit'];
         
    console.log("Received URL parameters  q=" + queryKeyword +
            " storeid=" + storeid + " customerid=" + customerid + " custsegmentid=" +
            custsegmentid + " discountlevel=" + discountlevel + " start=" + start + " showsolrreq=" + showsolrreq);

    if (typeof start === 'undefined') {
        start = 0;
        console.log("setting start to 0");
    }
    console.log ("rows:"+rows);
    
    var solrQuery = prepareOnlyBQOnlyQueryExt2(customerid, storeid, discountlevel, custsegmentid, queryKeyword, start,facetQueryPair);
    var solrURL = "http://" + host + ":" + port + getSolrPath("Prod") + solrQuery+"&rows="+rows+debugOpts;
    console.log("Sending solrURL=" + solrURL);
    return solrURL;
}
;

function handleSortSolrRequest(postBody)
{

    var start = 0;
    var queryKeyword = postBody["keyword"];
    var customerid = postBody["customerId"];
    var storeid = postBody["store"];
    var custsegmentid = postBody["customerSegment"];
    var discountlevel = postBody["campaignSensitivity"];
    var sortkeyword = postBody['sortkeyword'];
    var showsolrreq = false;
    var debug = postBody["debug"];
    
    var debugOpts = "";
    if (typeof debug !== 'undefined' && debug){
        debugOpts = "&indent=true&debugQuery=true&debug.explain.structured=true"; 
    }
    
    
    var facetList = getPostedFacetQueryParam(postBody);
    
    console.log("Received URL parameters  q=" + queryKeyword +
            " storeid=" + storeid + " customerid=" + customerid + " custsegmentid=" +
            custsegmentid + " discountlevel=" + discountlevel + " start=" + start + " showsolrreq=" + showsolrreq);

    if (typeof start === 'undefined') {
        start = 0;
        console.log("setting start to 0");
    }

    var solrQuery = prepareSolrSortQuery(customerid, storeid, custsegmentid, queryKeyword, start,sortkeyword,facetList);
    var solrURL = "http://" + host + ":" + port + getSolrPath("Prod") + solrQuery+debugOpts;
    console.log("Sending solrURL=" + solrURL);
    return solrURL;
}; 

function prepareSolrSortQuery(customerid, storeid, custsegmentid, queryKeyword, start,sortkeyword,facetList)
{
    //calculate facet boolean expression
   //var fPair = makeFilterBooleanExpr (facetList,customerid);
   var fPair = makeFilterBooleanExprTagExclude(facetList,customerid,storeid); 
    
   if (sortkeyword.match(/Price/)){
        sortkeyword = sortkeyword.replace(" ","_"+storeid+" ");
   }else if (sortkeyword.match(/ProductModelName/)){
       sortkeyword = sortkeyword.replace(" ","_Sort ");
   }
   //facetVal.constructor === Array
   //Add facting fields
    var faceFields = addFacetingFields (storeid,customerid,custsegmentid,fPair);
  
    fPair = fPair.join("&"); 
    queryKeyword = encodeURIComponent(queryKeyword);
    var fl = "fl=" + flList.join(",").replace(/SEGMENTID/g, custsegmentid).replace(/STOREID/g, storeid).replace(/CUSTOMERID/g,customerid) + ",score";
    var extraOpts = "wt=json&indent=true&stopwords=true&start=" + start;
    var solrURL = "q=StoreID:" + storeid + " AND (turkishtext:" + queryKeyword + " OR text:" + queryKeyword + ")&" + fl + "&"+fPair+"&" + extraOpts;
    solrURL = solrURL + "&" + faceFields+"&sort="+sortkeyword;

    return solrURL;

};

/**
    * 
    * @returns {undefined}
    */
   function reloadRankingProcessRequest(response,req){
        reloadRankingProcess ();
        
        response.writeHead(200, {"Content-Type": "text/html;charset=UTF-8"});
        response.write(html);
        response.end();
   };
    
   function reloadRankingProcess(){
        var solrBody;
        var campaignUrl = "http://"+host+":"+port+"/migrossolr/Config/select?q=section:ranking&wt=json&indent=true&rows=80" ;
        console.log ("Using "+campaignUrl);
        requestmod({ uri:campaignUrl}, function (error, response, body) {
            solrBody = body;
            console.log(body);
        });
        while(solrBody === undefined) {
          require('deasync').runLoopOnce();
        }
        var solrdata = JSON.parse(solrBody);
        //modify ranking values
        var docs = solrdata.response.docs;
        for (var docIndex in docs ){
            var rankName = docs[docIndex].property;
            var rankVal =  docs[docIndex].value_i;
            console.log(rankName +" set to "+rankVal);
            rankOrder [rankName] = rankVal;
        }
         
   };
   
exports.prepareSOLRQuery = prepareSOLRQuery;
exports.getFL = getFL;
exports.prepareBrowseQuery = prepareBrowseQuery;
exports.prepareReRankSOLRQuery = prepareReRankSOLRQuery;
exports.prepareBQOnlySOLRQuery = prepareBQOnlySOLRQuery;
exports.prepareBQOnlySOLRQuery2 = prepareBQOnlySOLRQuery2;
exports.handlePostSolrRequest = handlePostSolrRequest;
exports.handleSortSolrRequest = handleSortSolrRequest;
exports.getFacetQueryParam = getFacetQueryParam;
exports.prepareSuggestQuery = prepareSuggestQuery;
exports.reloadRankingProcessRequest=reloadRankingProcessRequest;
exports.reloadRankingProcess=reloadRankingProcess;
