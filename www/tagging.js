

function cpan_forum_get_xmlHttp() {
  var xmlHttp;
  try {
    // Firefox, Opera 8.0+, Safari
    xmlHttp=new XMLHttpRequest();
  }
  catch (e) {
    // Internet Explorer
    try {
      xmlHttp=new ActiveXObject("Msxml2.XMLHTTP");
    }
    catch (e) {
      try {
        xmlHttp=new ActiveXObject("Microsoft.XMLHTTP");
      }
      catch (e) {
        return false;
      }
    }
  }
  return xmlHttp;
}

// receives a url to request and function to be executed on response
function cpan_forum_ajaxFunction(url, action) {
    var xmlHttp = cpan_forum_get_xmlHttp();
    if (xmlHttp == false) {
        alert("Your browser does not support AJAX!");
        return;
    }
    xmlHttp.onreadystatechange=function() {
        if(xmlHttp.readyState==4) {
            action(xmlHttp.responseText);
        }
    }
alert(url);
    xmlHttp.open("GET", url, true);
    xmlHttp.send(null);
}


function cpan_forum_get_distros_by_tag(tag) {
    var distros = Array("CPAN-Forum", "Test-Simple");
    return distros;
}

