var greeting = 'Rawaha';
var name = 'Muhammad';
var massage =', please check your order';
var welcome = greeting + name + massage;



var sign = 'Montague House';
var tiles = sign.length;
var subTotal = tiles * 5;
var shipping = 7;
var grandTotal = subTotal + shipping;

var el = document.getElementById('greeting');
el.textContent = welcome;


var elSign = document.getElementById('userSign');
elSign.textContent = sign;

var eltiles = document.getElementById('tiles');
eltiles.textContent = tiles;

var elSubtotal = document.getElementById('subTotal');
elSubtotal.textContent = '$' + subTotal;

var elShipping = document.getElementById('shipping');
elShipping.textContent = '$' + shipping;


var elGrandTotal = document.getElementById('grandTotal');
elGrandTotal.textContent = '$' + grandTotal;



function getSize (width, height, depth ) {
      var area = width * height;
      var volume = width * height * depth;
      var sizes = [area, volume];
      return sizes;
}
var areaOne = getSize (3, 5, 7) [0];
var volumeOne = getSize (3, 5 ,7) [1];