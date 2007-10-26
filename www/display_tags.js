var cpan_forum_url = "http://cgi.cpanforum.local/";

function cpan_forum_list_tags() {
    //alert("test");
    //alert(action);
    //var url = document.URL;
    //var url = cpan_forum_url;//+ "rm=tags_of&amp;distro=" + distro;
    //cpan_forum_ajaxFunction(url, function(response) {
    // this is built by the application
    //var response = "test,testing,web,app devx";
    var response = cpan_forum_tags;
    var tags = response.split(",");
    // TODO return will not be simple array, it will be a hash with values such as the density of tags
    //var tags = new Array({"one":1, "two":2, "apple":3, "x":3});
    //tags.sort();
    //alert(tags.join());
    //var tags = new Array("xtest", "testing", "web", "app dev");
    //action(tags);
    //});
    return tags;
}

function cpan_forum_show_tags_as_li() {
    var tags = cpan_forum_list_tags()
    var t =  document.getElementById('cpanforum_tags');
    for(var i=0; i<tags.length; i++) {
        //alert(tags[i]);
        li = document.createElement('li');
        a  = document.createElement('a');
        a.setAttribute('href', 'javascript:cpan_forum_popup_tag("' + tags[i] + '")');
        var text = document.createTextNode(tags[i]);
        a.appendChild(text);
        li.appendChild(a);
        t.appendChild(li);
    }
//    alert(tags.length);
}

function cpan_forum_popup_tag(tag) {
    var w = window.open(cpan_forum_url, 'cpan_forum_list_distros', "width=600,height=300");
    //w.document.write("Tag: '" + tag + "'<br/>");
    //var distros = cpan_forum_get_distros_by_tag(tag);
    //for(var i=0; i<distros.length; i++) {
    //    w.document.write('<a href="/dist/' + distros[i] + '">' + distros[i] + '</a><br>');
    //}
}

