$(function() {
  $('a.alert-link.error-details').click(function() {
    var errorDetails = $(this).parents("div.alert").find("div.error-details");
    if(errorDetails.hasClass("hidden")) {
      errorDetails.removeClass("hidden");
    } else {
      errorDetails.addClass("hidden");
    }    
    return false;
  });
});