var dayRadio;
var dayForm;
var studentRadio;
var studentForm;

function handleRadioChanged() {
    if (dayRadio.checked)
        dayForm.style.display = ""; 
    else
        dayForm.style.display = "none"; 
    if (studentRadio.checked)
        studentForm.style.display = ""; 
    else
        studentForm.style.display = "none"; 
}

function init() {
    dayForm = document.getElementById('day_radio_form');
    dayForm.style.display = "none";
    dayRadio = document.getElementById('day_radio');
    studentForm = document.getElementById('student_radio_form');
    studentForm.style.display = "none";
    studentRadio = document.getElementById('student_radio');
    radios = document.getElementsByName('action');
    for (var i = 0;i < radios.length;++i) {
        radios[i].addEventListener("change", handleRadioChanged); 
    }
    handleRadioChanged();
}
document.addEventListener("DOMContentLoaded", init);
