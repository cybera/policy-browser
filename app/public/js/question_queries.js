function updateQuality(element, quality) {
  var link_quality = parseFloat($(element).attr("prop-quality"));
  if(quality >= link_quality - Number.EPSILON) {
    $(element).attr("href", $(element).attr("href").replace("/link", "/unlink"));
    $(element).find("span.glyphicon").removeClass("glyphicon-star-empty");
    $(element).find("span.glyphicon").addClass("glyphicon-star");
  } else {
    $(element).attr("href", $(element).attr("href").replace("/unlink", "/link"));
    $(element).find("span.glyphicon").removeClass("glyphicon-star");
    $(element).find("span.glyphicon").addClass("glyphicon-star-empty");
  }
}

$(function() {
  $('a.query-link-toggle').click(function() {
    $.ajax({
      type: "POST",
      url: $(this).attr("href"),
      context: this,
      async: true,
      success: function(data){
        updateQuality(this, data.quality);
        $(this).siblings("a.query-link-toggle").each(function(index, element) {
          updateQuality(element, data.quality);
        });
      }
    });
    return false;
  });
});