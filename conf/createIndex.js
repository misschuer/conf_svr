// 对Date的扩展，将 Date 转化为指定格式的String
// 月(M)、日(d)、小时(h)、分(m)、秒(s)、季度(q) 可以用 1-2 个占位符， 
// 年(y)可以用 1-4 个占位符，毫秒(S)只能用 1 个占位符(是 1-3 位的数字) 
// 例子： 
// (new Date()).Format("yyyy-MM-dd hh:mm:ss.S") ==> 2006-07-02 08:09:04.423 
// (new Date()).Format("yyyy-M-d h:m:s.S")      ==> 2006-7-2 8:9:4.18 
Date.prototype.Format = function (fmt) {
    var o = {
        "M+": this.getMonth() + 1, //月份 
        "d+": this.getDate(), //日 
        "h+": this.getHours(), //小时 
        "m+": this.getMinutes(), //分 
        "s+": this.getSeconds(), //秒 
        "q+": Math.floor((this.getMonth() + 3) / 3), //季度 
        "S": this.getMilliseconds() //毫秒 
    };
    if (/(y+)/.test(fmt)) fmt = fmt.replace(RegExp.$1, (this.getFullYear() + "").substr(4 - RegExp.$1.length));
    for (var k in o){
        if (new RegExp("(" + k + ")").test(fmt)) {
            fmt = fmt.replace(RegExp.$1, (RegExp.$1.length == 1) ? (o[k]) : (("00" + o[k]).substr(("" + o[k]).length)));
        }
    }
    
    return fmt;
}

function createIndex(coll,key){
    var hasIndex = false;
    coll.getIndexes().forEach(function(it){
        if(it.name == key+"_1") hasIndex = true;
    });
    if (hasIndex) return;
    var o = {};
    o[key] = 1;
    coll.ensureIndex(o);
    print("create OK:",key);
}

function createUnionIndex(coll,key1,key2){
    var hasIndex = false;
    coll.getIndexes().forEach(function(it){
        if(it.name == key1+"_1_"+key2+"_1") hasIndex = true;
    });
    if (hasIndex) return;
    var o = {};
    o[key1] = 1;
	o[key2] = 1;
    coll.ensureIndex(o);
    print("create OK:",key1,key2);
}


var coll_name1 = "gm_level";
var coll1 = db.getMongo().getDB("gm_intf").getCollection(coll_name1);
createIndex(coll1,"i_status");

var coll_name2 = "gm_kicking";
var coll2 = db.getMongo().getDB("gm_intf").getCollection(coll_name2);
createIndex(coll2,"i_status");

var coll_name3 = "gm_gag";
var coll3 = db.getMongo().getDB("gm_intf").getCollection(coll_name3);
createIndex(coll3,"i_status");

var coll_name4 = "gm_lock_account";
var coll4 = db.getMongo().getDB("gm_intf").getCollection(coll_name4);
createIndex(coll4,"i_status");
createIndex(coll4,"id");

var coll_name5 = "gm_notice";
var coll5 = db.getMongo().getDB("gm_intf").getCollection(coll_name5);
createIndex(coll5,"i_status");
createIndex(coll5,"id");

var coll_name6 = "gm_qq_config";
var coll6 = db.getMongo().getDB("gm_intf").getCollection(coll_name6);
createIndex(coll6,"i_status");
createIndex(coll6,"server_name");

var coll_name7 = "gm_gift_packs";
var coll7 = db.getMongo().getDB("gm_intf").getCollection(coll_name7);
createUnionIndex(coll7, "i_status", "u_end_time")

var coll_name8 = "gm_recharge";
var coll8 = db.getMongo().getDB("gm_recharge").getCollection(coll_name8);
createUnionIndex(coll8, "i_status", "u_adddate")

//特殊掉落已迁移到world_conf_svr
//var coll_name9 = "special_drop_confg";
//var coll9 = db.getMongo().getDB("gm_intf").getCollection(coll_name9);
//createIndex(coll9,"status");

//ar coll_name10 = "special_drop_ratio";
//var coll10 = db.getMongo().getDB("gm_intf").getCollection(coll_name10);
//createIndex(coll10,"status");

//var coll_name11 = "special_drop_orders";
//var coll11 = db.getMongo().getDB("gm_intf").getCollection(coll_name11);
//createIndex(coll11,"status");

var coll_name12 = "gm_inaccount_list";
var coll12 = db.getMongo().getDB("gm_intf").getCollection(coll_name12);
createIndex(coll12,"i_status");
createIndex(coll12,"account");

