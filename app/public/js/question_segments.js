function toggle_collapse_all(element_id) {
  var link = $("#" + element_id);
  var state = link.attr("accordian-state");
  $("#"+element_id+" .panel-collapse").collapse(state);
  if(state == "hide") {
    state = "show";
  } else {
    state = "hide";
  }
  link.attr("accordian-state", state);
}

$(function() {
  $('#question-segments-categories-collapse-all').click(function() {
    toggle_collapse_all("question-segments-categories");
    return false;
  });
  $('#question-segments-organizations-collapse-all').click(function() {
    toggle_collapse_all("question-segments-organizations");
    return false;
  });
});