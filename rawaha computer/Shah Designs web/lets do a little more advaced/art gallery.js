const box2 = document.getElementById("box2-image");
      Image.onerror = function () {
            image.src = "fallback.jpg";
      }