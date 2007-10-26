var cpan_forum_url = "http://cgi.cpanfoum.local/m?";


function cpan_forum_list_tags(distro) {
    //alert("test");
    var url = cpan_forum_url + "rm=tags_of&amp;distro=" + distro;
    var tags = new Array("test", "testing", "web", "app dev");
    return tags;
}

function cpan_forum_show_tags_as_li(distro) {
    var tags = cpan_forum_list_tags(distro);
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
    var w = window.open('', 'cpan_forum_list_distros', "width=600,height=300");
    w.document.write("Tag: '" + tag + "'<br/>");
    var distros = cpan_forum_get_distros_by_tag(tag);
    for(var i=0; i<distros.length; i++) {
        w.document.write('<a href="/dist/' + distros[i] + '">' + distros[i] + '</a><br>');
    }
}

function cpan_forum_get_distros_by_tag(tag) {
    var distros = Array("CPAN-Forum", "Test-Simple");
    return distros;
}

