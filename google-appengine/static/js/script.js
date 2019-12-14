var dayRadio;
var bdayForm;
var studentRadio;
var studentForm;
var monthRadio;

var dayForm;
var monthForm;
var yearForm;

function handleRadioChanged() {
    if (dayRadio.checked) {
        dayForm.style.display = "";
        monthForm.style.display = "";
        yearForm.style.display = "";
    }
    else if (monthRadio.checked) { 
        dayForm.style.display = "none";
        monthForm.style.display = "";
        yearForm.style.display = "";
    }
    else {
        dayForm.style.display = "none";
        monthForm.style.display = "none";
        yearForm.style.display = "none";
    }
    if (studentRadio.checked) {
        studentForm.style.display = ""; 
    }
    else {
        studentForm.style.display = "none"; 
    }
}

function init() {
    dayForm = document.getElementById('day');
    dayForm.style.display = "none";
    monthForm = document.getElementById('month');
    monthForm.style.display = "none";
    yearForm = document.getElementById('year');
    yearForm.style.display = "none";

    //bdayForm = document.getElementById('day_radio_form');
    //bdayForm.style.display = "none";
    monthRadio = document.getElementById('month_radio');
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
