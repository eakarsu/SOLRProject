/* 
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

var rankingProcess = require("./rankingProcess");
function test ()
{
    var list = rankingProcess.flList;
    for (field in list){
        console.log ("debug field="+field+" = "+list[field]);
    }
};