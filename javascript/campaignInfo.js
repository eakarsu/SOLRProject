/*
 * 
 * Kampanya algoritmasi
 * Represent campaingns in json format
 * campaigns:
 * {
 *      "sut":
 *      {
 *       dateRange:[2015-03-30,2015-04-10]  
 *       products:[938938,5555,555553]
 *      },
 *      "peynir":
 *      {
 *       dateRange:[2015-03-30,2015-04-10] 
 *       products:[938938,5555,555553]
 *      }   
 * }
 * We need to add new filed "ISInCampaign" to specify whether or not a product is in campaign
 * Check searched keywwork matches any campaign keyword if (!defined campaingns[keyword])
 * If match found, then get products in that compaign, randomly pick one (generate random number between 1 to products.length)
 * Prefix a boost query for the selected product, highest score like this, let say we picked product id 55555
 * "{!edismax}(ProductID:55555 AND InCampaign:true)^MAX_VAL";
 * Send SOLR query
 * If we had match found for campaing keyword, then swap first and third element so third element will be always from campain
 * If there was co campaing keyword match found, then normal path followed.
 * 
 * 
 */

Turkish =  {}; Turkish.latin_map = {"ç":"c","Ç":"C","ğ":"g","Ğ":"G","ı":"i","İ":"I","ö":"o","Ö":"O","ş":"s","Ş":"S","ü":"u","Ü":"U"};
String.prototype.turkish = function () {
    return this.replace(/[^A-Za-z0-9\[\] ]/g, function (a) {
        return Turkish.latin_map[a] || a;cay
    });
};

   var campaigns = {
      "ariel":
      {
        "dateRange": "",
        "productIDs":["852106","852108","852105","497388","795642"]
      },
      "peynir":
      {
        "dateRange": "",
        "productIDs":["808938","809915","845991","791714","775152"]
      },
       "çay":
      {
        "dateRange": "",
        "productIDs":["110984","699845","745870","818527"]
      },
      "cay":
      {
        "dateRange": "",
        "productIDs":["110984","699845","745870","818527"]
      },
      
        "pilic":
      {
        "dateRange": "",
        "productIDs":["415527","213916","194767","213937","180149"]
      }
   }; 
      
   var exactMatchMultiplier = 2;
       
   function getExactMatchMultiplier ()
   {
       return exactMatchMultiplier;
   };
   
    function whichSearchedWord (keyword)
   {
       var searchedWord = "";
       keyword = keyword.toLowerCase();
       var words = keyword.split(" ");
       for (var k in words){
          var nextWord = words[k];
          var trkeyword = nextWord.turkish();
          var isFound = ((typeof campaigns[nextWord] !== 'undefined') || (typeof campaigns[trkeyword] !== 'undefined')); 
          if (isFound){
              searchedWord = nextWord;
          }
       }
       return searchedWord;
   };
   
   function isInCampaign (keyword)
   {
       var foundWord = whichSearchedWord(keyword);
       return foundWord.length > 0;
   };
   
   function getProductIDs (keyword)
   {
       keyword = whichSearchedWord(keyword);
       if (keyword.length > 0){
            var trkeyword = keyword.turkish();
            var pids = [];
            if (typeof campaigns[keyword] !== 'undefined'){ 
              pids = campaigns[keyword]["productIDs"];
            } else {
              pids = campaigns[trkeyword]["productIDs"];
            }
            return  pids;
        }
        else
            return [];
   };
   
   function getForCampaignQueryInfo (searchKeyword,multiplier,highestRank,promMaxRankVal)
   {
           
        var campaignQuery = "campaignQuery={!edismax  bf=''}ProductID:PRODUCTID AND IsInCampaign:true";
        var campaignExpr = "map(exists($campaignQuery),1,1,"+promMaxRankVal+",0)^";
      
        searchKeyword = searchKeyword.toLocaleLowerCase();
          
        if (isInCampaign(searchKeyword)){
            
            var pids = getProductIDs(searchKeyword);
            var maxVal = pids.length;
            var rval = Math.random();
            var index = Math.floor(rval * maxVal);
            var promotedProductID = pids[index];
            console.log("MATCHED To CAMPAIGN keyword:"+searchKeyword+":"+promotedProductID+":"+maxVal+":"+index+":"+rval);
            var rankVal = Math.pow(multiplier, 2*highestRank + 2);
            campaignQuery = campaignQuery.replace(/PRODUCTID/,promotedProductID);
            campaignExpr = campaignExpr+rankVal;
            return [campaignExpr,campaignQuery];
        }
        return [];
    };
    
   exports.isInCampaign = isInCampaign;
   exports.getProductIDs = getProductIDs;
   exports.getForCampaignQueryInfo = getForCampaignQueryInfo;
   exports.getExactMatchMultiplier = getExactMatchMultiplier;
   
/*
   <add>
    <doc>
      <field name="ProductID">814048</field>
      <field name="IsInCampaign" update="set">true</field>
    </doc>
    <doc>
      <field name="ProductID">795634</field>
      <field name="IsInCampaign" update="set">true</field>
    </doc>
    <doc>
      <field name="ProductID">808490</field>
      <field name="IsInCampaign" update="set">true</field>
    </doc>
    <doc>
      <field name="ProductID">799467</field>
      <field name="IsInCampaign" update="set">true</field>
    </doc>
    <doc>
      <field name="ProductID">795641</field>
      <field name="IsInCampaign" update="set">true</field>
    </doc>
</add>
*/ 