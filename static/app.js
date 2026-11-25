(function () {
  "use strict";

  var root = document.documentElement;
  var themeButton = document.getElementById("theme-toggle");
  var menuButton = document.getElementById("menu-toggle");

  function currentTheme() {
    return root.dataset.theme === "dark" ? "dark" : "light";
  }

  function setCookie(name, value, days) {
    var expires = "";
    if (days) {
      var date = new Date();
      date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
      expires = "; expires=" + date.toUTCString();
    }
    document.cookie = name + "=" + (value || "") + expires + "; path=/";
  }

  function getCookie(name) {
    var nameEQ = name + "=";
    var ca = document.cookie.split(";");
    for (var i = 0; i < ca.length; i++) {
      var c = ca[i];
      while (c.charAt(0) === " ") {
        c = c.substring(1, c.length);
      }
      if (c.indexOf(nameEQ) === 0) {
        return c.substring(nameEQ.length, c.length);
      }
    }
    return null;
  }

  function setTheme(theme) {
    root.dataset.theme = theme;
    setCookie("gl-theme", theme, 365);
  }

  function initTheme() {
    var stored = getCookie("gl-theme");
    if (stored === "dark" || stored === "light") {
      root.dataset.theme = stored;
    } else if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
      root.dataset.theme = "dark";
    }
  }

  initTheme();

  if (themeButton) {
    themeButton.addEventListener("click", function () {
      setTheme(currentTheme() === "dark" ? "light" : "dark");
    });
  }

  function setNavigation(open) {
    document.body.classList.toggle("nav-open", open);
    if (menuButton) {
      menuButton.setAttribute("aria-expanded", open ? "true" : "false");
    }
  }

  if (menuButton) {
    menuButton.addEventListener("click", function () {
      setNavigation(!document.body.classList.contains("nav-open"));
    });
  }

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") {
      setNavigation(false);
    }
  });

  document.addEventListener("click", function (event) {
    if (!document.body.classList.contains("nav-open")) {
      return;
    }
    if (event.target.closest("#sidebar") || event.target.closest("#menu-toggle")) {
      return;
    }
    setNavigation(false);
  });

  document.querySelectorAll(".sidebar-nav a").forEach(function (link) {
    link.addEventListener("click", function () {
      setNavigation(false);
    });
  });

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
      var area = document.createElement("textarea");
      area.value = text;
      area.setAttribute("readonly", "");
      area.style.position = "fixed";
      area.style.opacity = "0";
      document.body.appendChild(area);
      area.select();
      try {
        document.execCommand("copy");
        resolve();
      } catch (error) {
        reject(error);
      } finally {
        document.body.removeChild(area);
      }
    });
  }

  document.querySelectorAll(".markdown pre").forEach(function (block) {
    var button = document.createElement("button");
    button.type = "button";
    button.className = "copy-button";
    button.textContent = "Copy";
    button.setAttribute("aria-label", "Copy code to clipboard");

    button.addEventListener("click", function () {
      var code = block.querySelector("code");
      var text = code ? code.innerText : block.innerText;
      copyText(text).then(
        function () {
          button.textContent = "Copied";
          window.setTimeout(function () {
            button.textContent = "Copy";
          }, 1400);
        },
        function () {
          button.textContent = "Failed";
          window.setTimeout(function () {
            button.textContent = "Copy";
          }, 1400);
        }
      );
    });

    block.appendChild(button);
  });
})();
