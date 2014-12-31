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

var host = '192.168.191.141';
//var host = 'localhost';
var port = '8080';
var solrpath = '/migrossolr/ProductsTRMorphFullProduction4/myselect?';
var basepath = "/arabul?";
var gradeWindowLen = 5;
var reRankDocs = 5000;
var reRankWeight = 1000;

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
    NumberOfClicksGrade: 7,
    AmountGrade: 8,
    OrderCountGrade: 9,
    BrandName: 10,
    BrandName_TR: 10,
    ProductFeatures: 10,
    ProductFeatures_TR: 10,
    ProductMoreDetailExact: 10,
    ProductMoreDetailExact_TR: 10,
    ProductMoreDetail: 10,
    ProductMoreDetail_TR: 10,
    Description: 10,
    Description_TR: 10,
    ProductProperty: 10,
    ProductProperty_TR: 10};

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
    //'ProductMoreDetail',
    'Description',
    'ProductProperty',
    'UnitSymbol',
    'UnitVal',
    'UnitExpr',
    'PathLevel2',
    'IsMigroskop',
    'Price_STOREID',
    'InStock_STOREID',
    'PSIID_STOREID',
    'InPromotion_STOREID',
    'myFavorites:exists(query({!v="CustomersFavourite:CUSTOMERID"}))',
    'myOldOrders:exists(query({!v="CustomersPurchased:CUSTOMERID"}))'
];
 

var qlList = [
    'ProductMoreDetailExact',
    'ProductModelNameExact',
    'ProductModelName',
    'BrandName',
    'ProductFeatures',
    'ProductMoreDetail',
    'Description',
    'ProductProperty',
    'ProductModelName',
    'BrandName_TR',
    'ProductFeatures_TR',
    'ProductMoreDetail_TR',
    'Description_TR',
    'ProductProperty_TR'
];
  
var facetFields = [
    'IsMCCProduct_STOREID',
    'UnitSymbol',
    'IsMigroskop',
    'CustomersPurchased',
    'CustomersFavourite',
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
    'ProductProperty_Facet'
];


//InPromotion_STOREID with rankling  4,7 or 9 will be inserted based on the discountPrefLev - discount prefrence level-kampanya duyarliligi 
//and all other adjusted


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

function getConstVal(index, sortedRankOrder, highestRank)
{
    var constVal = "1";
    for (var j = parseInt(index) + 1; j < sortedRankOrder.length; j++) {
        var field = sortedRankOrder[j].key;
        if (field.match(/Grade/)) {
            var localRankLevel = sortedRankOrder[j].value;
            constVal = Math.pow(4, (highestRank - localRankLevel + 1)) + 4;
            break;
        }
    }
    return constVal;

}

function prepareExceptionRankingForBF(allSortExprs, sortedRankOrder, sortExpr, sortExpr2, customerid)
{
    var highestRank = sortedRankOrder[sortedRankOrder.length - 1].value;

    for (var index in sortedRankOrder) {
        var field = sortedRankOrder[index].key;
        var rankLevel = sortedRankOrder[index].value;
        var rankVal = Math.pow(4, (highestRank - rankLevel));
        var nextRankVal = Math.pow(4, (highestRank - rankLevel + 1));

        //All numeric values here for all fields ending in "Grade". we need to scale the result to boost correctly
        if (field.match(/Grade/)) {
            var newFieldName = "scale(" + field.replace("Grade", "") + "," + rankVal + "," + (nextRankVal - 4) + ")";
            var sortExprTemp = sortExpr.replace("FIELDNAME", newFieldName);
            sortExprTemp = sortExprTemp + rankVal;
            allSortExprs.push(sortExprTemp);
        } else if (field.match(/InPromotion/)) {
            var constVal = getConstVal(index, sortedRankOrder, highestRank);

            var sortExprTemp = sortExpr2.replace("FIELDNAME", field).replace("CONST", constVal);
            sortExprTemp = sortExprTemp.replace("FIELDVALUE", "true");
            sortExprTemp = sortExprTemp + rankVal;
            allSortExprs.push(sortExprTemp);
        }
        else if (field.match(/Customers/) && ((typeof customerid !== 'undefined') && customerid !== "")) {
            var constVal = getConstVal(index, sortedRankOrder, highestRank);
            var sortExprTemp = sortExpr2.replace("FIELDNAME", field).replace("CONST", constVal);
            sortExprTemp = sortExprTemp.replace("FIELDVALUE", customerid);
            sortExprTemp = sortExprTemp + rankVal;
            allSortExprs.push(sortExprTemp);
        }
    }
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

    var qq = "{!edismax bf=''}ProductModelName:KEYWORD OR ProductModelName_TR:KEYWORD";
    var exactqq = "{!edismax bf=''}ProductModelNameExact:\"KEYWORD\" OR ProductModelName_TR:\"KEYWORD\"";
    var sortExpr = "map(exists($qq),1,1,FIELDNAME,0)^";
    var sortExpr2 = "product(map(and(termfreq(FIELDNAME,FIELDVALUE),exists($qq)),1,1,1,0),CONST)^";
    var exactSortExpr = "map(exists($exactqq),1,1,FIELDNAME,0)^";
    var exactSortExpr2 = "product(map(and(termfreq(FIELDNAME,FIELDVALUE),exists($exactqq)),1,1,1,0),CONST)^";

    searchKeywordEncoded = encodeURIComponent(searchKeyword);
    exactqq = exactqq.replace(/KEYWORD/g, searchKeywordEncoded);
    qq = qq.replace(/KEYWORD/g, searchKeywordEncoded);

    allSortExprs = [];
    var sortedRankOrder = sortObject(localRankOrder);

    /*for (x in sortedRankOrder) {
        console.log(" sorted: " + sortedRankOrder[x].key + ":" + sortedRankOrder[x].value);
    }
    */
   
    prepareExceptionRankingForBF(allSortExprs, sortedRankOrder, exactSortExpr, exactSortExpr2, customerid);
    prepareExceptionRankingForBF(allSortExprs, sortedRankOrder, sortExpr, sortExpr2, customerid);

    qq = "qq=" + qq;
    exactqq = "exactqq=" + exactqq;
    var result = "bf=" + allSortExprs.join(" ") + "&" + qq + "&" + exactqq;

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

function prepareOnlyBQOnlyQueryExt2(customerid, storeid, discountPrefLev, custsegmentid, queryKeyword, start,facetList)
{
   
   //facetVal.constructor === Array
    var fPair = "";
    for (var prop in facetList){
        var facetVal = facetList[prop];
        if (facetVal.constructor === Array){
            for (var inprop in facetVal){
                fPair = fPair.concat(" AND "+prop+":"+encodeURIComponent(facetVal[inprop]));
            }
        }else
            fPair = fPair.concat(" AND "+prop+":"+encodeURIComponent(facetVal));
    }
    
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

    //Add facet.field=IsMigroskop after we add it to indexinf process
    //f.CustomersPurchased.facet.prefix will returns only faceting results for field CustomersPurchased that includes customerid
    //f.CustomersFavourite.facet.prefix will returns only faceting results for field CustomersFavourite that includes customerid
    var facetFieldsList = facetFields.join("&facet.field=");
    var faceConfs = "facet=true&facet.mincount=1&facet.limit=100&facet.sort=count&f.CustomersPurchased.facet.prefix=" + customerid + "&f.CustomersFavourite.facet.prefix=" + customerid;
    ;
    var faceFields = faceConfs + "&facet.field=" + facetFieldsList;

    faceFields = faceFields.replace(/STOREID/g, storeid);
    faceFields = faceFields.replace(/SEGMENTID/g, custsegmentid);

    //debuggin bf parameters for now with boosting instead of sorting */
    //var sortQuery = prepareSortExpression2(localRankOrder,customerid,queryKeyword);
    var sortQuery = prepareBFExpression2(localRankOrder, customerid, queryKeyword);

    var pfqfOnlyQuery = preparePFQFQuery(localRankOrder);
 
    queryKeyword = encodeURIComponent(queryKeyword);
    var fl = "fl=" + flList.join(",").replace(/SEGMENTID/g, custsegmentid).replace(/STOREID/g, storeid) + ",score";
    var extraOpts = "wt=json&indent=true&stopwords=true&start=" + start;
    var solrURL = "q=StoreID:" + storeid + fPair+" AND (turkishtext:" + queryKeyword + " OR text:" + queryKeyword + ")&" + fl + "&" + sortQuery + "&" + pfqfOnlyQuery + "&" + extraOpts;
    solrURL = solrURL + "&" + faceFields + "&" + hlPars;

    return solrURL;

}
;

function prepareBrowseQuery(query)
{
    var queryKeyword = query.q;
    var customerid = query.customerid;
    var storeid = query.storeid;
    var custsegmentid = query.custsegmentid;
    var discountlevel = query.discountlevel;

    /* q=kurabiye&startindex=0&endindex=10&customerid=127066&storeid=2185&discountlevel=1&custsegmentid=107&start=10 */
    var browseURL = basepath + "q=" + queryKeyword + "&customerid=" + customerid + "&storeid=" + storeid + "&discountlevel=" +
            discountlevel + "&custsegmentid=" + custsegmentid + "&";
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
    var solrURL = "http://" + host + ":" + port + solrpath + solrQuery;
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
    var solrURL = "http://" + host + ":" + port + solrpath + solrQuery;
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
    var solrURL = "http://" + host + ":" + port + solrpath + solrQuery;
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
        }else if (prop === isMcc || prop === isProm || prop.match(/UnitSymbol|IsMigroskop|BrandName|CustomersPurchased|CustomersFavourite|ProductProperty/)){
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
        {"k": "categories", "v": ["hazır çocuk yemekleri", "biberonlar"]},
        {"k": "brands", "v": ["milupa", "bebelac"]},
        {"k": "units", "v": ["kg", "gr"]},
        {"k": "productProperty", "v": ["?", "?", "?"]}
    ]
 */
function getPostedFacetQueryParam(postBody)
{
    
    var storeid = postBody["store"];
    var isMcc = "IsMCCProduct_" + storeid;
    var isProm = "InPromotion_" + storeid;
    var facetList = {};
    var filters = postBody["filters"];
    for (var j in filters){
        var facetQuery = "";
        var facetVal = "";
        var allVals = "";
        if (filters[j]["k"] === "mcc") {
            facetQuery = isMcc;
            facetVal = filters[j]["v"];
            facetList[facetQuery] = facetVal;
        }else if (filters[j]["k"] === "units") {
            facetQuery = 'UnitSymbol';
            facetVal = filters[j]["v"];
             for (var k in facetVal){
                allVals=allVals.concat("\""+facetVal[k]+"\"");
            }
            facetList[facetQuery] = allVals;
        }else  if (filters[j]["k"] === "migroskop") {
            facetQuery = 'IsMigroskop';
            facetVal = filters[j]["v"];
            facetList[facetQuery] = facetVal;
        }else  if (filters[j]["k"] === "brands") {
            facetQuery = 'BrandName';
            facetVal = filters[j]["v"];
            for (var k in facetVal){
                 allVals=allVals.concat("\""+facetVal[k]+"\"");
            }
            facetList[facetQuery] = allVals;
        }else  if (filters[j]["k"] === "categories") {
            facetQuery = 'PathLevel2';
            facetVal = filters[j]["v"];
            for (var k in facetVal){
                allVals=allVals.concat("\""+facetVal[k]+"\"");
            }
            facetList[facetQuery] = allVals;
        }else  if (filters[j]["k"] === "myOldOrders") {
            facetQuery = 'CustomersPurchased';
            facetVal = filters[j]["v"];
            facetList[facetQuery] = facetVal;
        }else  if (filters[j]["k"] === "myFavorites") {
            facetQuery = 'CustomersFavourite';
            facetVal = filters[j]["v"];
            facetList[facetQuery] = facetVal;
        } else if (filters[j]["k"] === "inPromotion") {
            facetQuery = isProm;
            facetVal = filters[j]["v"];
            facetList[facetQuery] = facetVal;
        }else  if (filters[j]["k"] === "productProperty") {
            facetQuery = "ProductProperty";
            facetVal = filters[j]["v"];
            for (var k in facetVal){
                allVals=allVals.concat("\""+facetVal[k]+"\"");
            }
            facetList[facetQuery] = allVals;
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

    var solrQuery = prepareOnlyBQOnlyQueryExt2(customerid, storeid, discountlevel, custsegmentid, queryKeyword, start,facetQueryPair);
    var solrURL = "http://" + host + ":" + port + solrpath + solrQuery;
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

    var start = 0;
    var queryKeyword = postBody["keyword"];
    var customerid = postBody["customerId"];
    var storeid = postBody["store"];
    var custsegmentid = postBody["customerSegment"];
    var discountlevel = postBody["campaignSensitivity"];
    var showsolrreq = false;

    var facetQueryPair = getPostedFacetQueryParam(postBody);
    
    console.log("Received URL parameters  q=" + queryKeyword +
            " storeid=" + storeid + " customerid=" + customerid + " custsegmentid=" +
            custsegmentid + " discountlevel=" + discountlevel + " start=" + start + " showsolrreq=" + showsolrreq);

    if (typeof start === 'undefined') {
        start = 0;
        console.log("setting start to 0");
    }

    var solrQuery = prepareOnlyBQOnlyQueryExt2(customerid, storeid, discountlevel, custsegmentid, queryKeyword, start,facetQueryPair);
    var solrURL = "http://" + host + ":" + port + solrpath + solrQuery;
    console.log("Sending solrURL=" + solrURL);
    return solrURL;
}
;

exports.prepareSOLRQuery = prepareSOLRQuery;
exports.getFL = getFL;
exports.prepareBrowseQuery = prepareBrowseQuery;
exports.prepareReRankSOLRQuery = prepareReRankSOLRQuery;
exports.prepareBQOnlySOLRQuery = prepareBQOnlySOLRQuery;
exports.prepareBQOnlySOLRQuery2 = prepareBQOnlySOLRQuery2;
exports.handlePostSolrRequest = handlePostSolrRequest;
exports.getFacetQueryParam = getFacetQueryParam;
