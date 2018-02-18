$(function() {
  $('a.query-link-toggle').click(function() {
    $.ajax({
      type: "POST",
      url: $(this).attr("href"),
      context: this,
      async: true,
      success: function(data){
        if(data.linked) {
          $(this).attr("href", $(this).attr("href").replace("/link", "/unlink"));
          $(this).find("span.glyphicon").removeClass("glyphicon-star-empty");
          $(this).find("span.glyphicon").addClass("glyphicon-star");
        } else {
          $(this).attr("href", $(this).attr("href").replace("/unlink", "/link"));
          $(this).find("span.glyphicon").removeClass("glyphicon-star");
          $(this).find("span.glyphicon").addClass("glyphicon-star-empty");
        }
      }
    });
    return false;
  });
});