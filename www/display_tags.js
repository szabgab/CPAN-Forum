var cpan_forum_url = "http://cgi.cpanforum.local/";

function cpan_forum_list_tags() {
    var response = cpan_forum_tags;
    var tags = response.split(",");
    for(var i=0; i<tags.length; i++) {
        tags[i] = tags[i].split(":")[0];
    }
    // TODO return will not be simple array, it will be a hash with values such as the density of tags
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
        li = document.createElement('li');
        a  = document.createElement('a');
        a.setAttribute('href', 'javascript:cpan_forum_popup_tag("' + tags[i] + '")');
        var text = document.createTextNode(tags[i]);
        a.appendChild(text);
        li.appendChild(a);
        t.appendChild(li);
    }
    
    //text should be either add tags or update tags
    
    var link_text = (tags.length > 0 ? "update" : "add") + " tags";
    li = document.createElement('li');
    a  = document.createElement('a');
    a.setAttribute('href', 'javascript:cpan_forum_popup("' + "qq" + '")');
    var text = document.createTextNode(tags.length);
    a.appendChild(text);
    li.appendChild(a);
    t.appendChild(li);
}


function cpan_forum_popup_tag(tag) {
    var w = window.open(cpan_forum_url + '/tags/name_popup/' + tag, 'cpan_forum_list_distros', "width=600,height=300,resizable=1");
    w.focus(1);
}

