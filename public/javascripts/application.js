
$(document).on('ready', function(){
  $('[data-date]').text( moment($(this).data('date')).format('YYYY-MM-DD') );

});
