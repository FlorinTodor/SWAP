<?php
// Obtener la IP del servidor
$server_ip = $_SERVER['SERVER_ADDR'];
// Obtener el software del servidor
$server_software = $_SERVER['SERVER_SOFTWARE'];
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SWAP - Florin Emanuel Todor Gliga</title>
    <style>
        /* 🌙 MODO OSCURO ESTILO GITHUB */
        body {
            background-color: #0d1117;
            color: #c9d1d9;
            font-family: Arial, sans-serif;
            padding: 20px;
            margin: 0;
        }
        
        a {
            color: #58a6ff;
            text-decoration: none;
        }

        a:hover {
            text-decoration: underline;
        }

        h1, h2, h3 {
            color: #e6edf3;
        }

        p, ul {
            font-size: 16px;
        }

        hr {
            border-color: #30363d;
        }

        .container {
            max-width: 800px;
            margin: auto;
            padding: 20px;
            background: #161b22;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(255, 255, 255, 0.1);
        }

        .skills img {
            margin: 5px;
            border-radius: 5px;
            padding: 5px;
            background: #21262d;
        }

        .social-icons img {
            margin: 5px;
            border-radius: 5px;
            background: #21262d;
            padding: 5px;
        }

        .server-info {
            background: #21262d;
            padding: 15px;
            border-radius: 8px;
            text-align: center;
        }
    </style>
</head>
<body>

    <div class="container">
        <h1 align="center">Hi, I'm Florin Todor <img src="https://media.giphy.com/media/hvRJCLFzcasrR4ia7z/giphy.gif" width="35"></h1>

        <div class="server-info">
            <p><strong>SWAP - Florin Emanuel Todor Gliga</strong></p>
            <p><strong>La dirección IP del servidor es:</strong> <?php echo $server_ip; ?></p>
            <p><strong>El servidor está ejecutando:</strong> <?php echo $server_software; ?></p>
        </div>

        <hr>

        <h1><picture><img src = "https://user-images.githubusercontent.com/74038190/229223156-0cbdaba9-3128-4d8e-8719-b6b4cf741b67.gif" width = 50px></picture> About me</h1>
        <p>🎓 I'm currently studying a <a href="https://grados.ugr.es/Informatica_ADE/">Double Degree in Computer Science and Business Management at the University of Granada</a>.</p>

        <h2>🚀 Some things about me:</h2>
        <ul>
            <li>🚀 I like to learn about cybersecurity and artificial intelligence.</li>
            <li>🧑‍💻 I'm constantly improving my programming, data structures, and efficiency.</li>
            <li>📗 I am curious about Stoic philosophy and personal development.</li>
        </ul>

        <hr>

        <img src="https://media2.giphy.com/media/QssGEmpkyEOhBCb7e1/giphy.gif?cid=ecf05e47a0n3gi1bfqntqmob8g9aid1oyj2wr3ds3mg700bl&rid=giphy.gif" width ="25"><b>  Skills</b>
        <h2>💻 My programming languages</h2>
        <p class="skills">
        <img width="48" height="48" src="https://img.icons8.com/color/48/c-plus-plus-logo.png" alt="c-plus-plus-logo"/> <img width="48" height="48" src="https://img.icons8.com/color/48/c-programming.png" alt="c-programming"/> <img width="48" height="48" src="https://img.icons8.com/color/48/python--v1.png" alt="python--v1"/> <img width="48" height="48" src="https://img.icons8.com/color/48/java-coffee-cup-logo--v1.png" alt="java-coffee-cup-logo--v1"/> <img width="48" height="48" src="https://img.icons8.com/color/48/ruby-programming-language.png" alt="ruby-programming-language"/> <img width="48" height="48" src="https://img.icons8.com/fluency/48/bash.png" alt="bash"/> 
        </p>

        <h2>🛠 Software & Tools</h2>
        <p class="skills">
        <img width="48" height="48" src="https://img.icons8.com/color/48/git.png" alt="git"/> <img width="48" height="48" src="https://img.icons8.com/external-tal-revivo-bold-tal-revivo/48/FFFFFF/external-github-community-for-software-building-and-testing-online-logo-bold-tal-revivo.png" alt="external-github-community-for-software-building-and-testing-online-logo-bold-tal-revivo"/> <img width="48" height="48" src="https://nmap.org/images/sitelogo.png" alt="nmap"/> <img width="48" height="48" src="https://upload.wikimedia.org/wikipedia/commons/d/db/Wireshark_Icon.png" alt="wireshark"/><img width="48" height="48" src="https://img.icons8.com/color/48/virtualbox.png" alt="virtualbox"/><img width="48" height="48" src="https://img.icons8.com/color/48/old-vmware-logo.png" alt="old-vmware-logo"/>
            <img width="48" height="48" src="https://images.pling.com/img/00/00/13/91/38/1108377/110588-1.png" alt="wxmaxima"/> <img width="50" height="50" src="https://img.icons8.com/ios/50/FFFFFF/markdown--v2.png" alt="markdown--v2"/>
        </p>

        <h2>💻 IDEs</h2>
        <p class="skills">
        <img width="48" height="48" src="https://cdn.worldvectorlogo.com/logos/clion-1.svg" alt="clion"/>  <img width="48" height="48" src="https://img.icons8.com/color/48/pycharm--v1.png" alt="pycharm--v1"/><img width="48" height="48" src="https://img.icons8.com/fluency/48/intellij-idea.png" alt="intellij-idea"/>  <img width="48" height="48" src="https://static-00.iconduck.com/assets.00/rubymine-icon-512x512-0u05qc2i.png" alt="ruby-mine"/><img width="48" height="48" src="https://img.icons8.com/color/48/visual-studio-code-2019.png" alt="visual-studio-code-2019"/> <img width="48" height="48" src="https://img.icons8.com/color/48/code-blocks.png" alt="code-blocks"/><img width="48" height="48" src="https://img.icons8.com/color/48/apache-netbeans.png" alt="apache-netbeans"/> <img width="48" height="48" src="https://upload.wikimedia.org/wikipedia/commons/5/5d/Dev-C%2B%2B_logo.png" alt="code-blocks"/>
        </p>

        <h2>🖥 Operating Systems</h2>
        <p class="skills">
        <img width="48" height="48" src="https://img.icons8.com/plasticine/48/kali-linux.png" alt="kali-linux"/> <img width="48" height="48" src="https://img.icons8.com/color/48/parrot-security--v1.png"  alt="parrot-security--v1"/> <img width="48" height="48" src="https://img.icons8.com/color/48/ubuntu--v1.png" alt="ubuntu--v1"/> <img width="48" height="48" src="https://img.icons8.com/color/48/linux-mint.png" alt="linux-mint"/> <img width="48" height="48" src="https://img.icons8.com/?size=100&id=17847&format=png&color=000000" alt="redhat"/> <img width="48" height="48" src="https://img.icons8.com/fluency/48/windows-10.png" alt="windows-10"/>

        </p>

        <hr>

        <h1><img src="https://media.giphy.com/media/iY8CRBdQXODJSCERIr/giphy.gif" width="35"><b> GitHub Analytics  & Leetcode Stats &  Codewars Stats</b></h1>
        <p align="center">
            <a href="https://github.com/FlorinTodor">
                <img height="180em" src="https://github-readme-stats-eight-theta.vercel.app/api?username=FlorinTodor&show_icons=true&theme=algolia&include_all_commits=true&count_private=true"/>
                <img height="180em" src="https://github-readme-stats-eight-theta.vercel.app/api/top-langs/?username=FlorinTodor&layout=compact&langs_count=8&theme=algolia"/>
            </a>
            <br>
            <a href="https://leetcode.com/FlorinTodor/">
                <img src="https://leetcode.card.workers.dev/FlorinTodor?theme=forest&font=baloo&extension=null" height="180em"/>
            </a>
        </p>

        <hr>

        <h1>📞 Connect with me</h1>
        <p class="social-icons">
            <a href="mailto:florintodorgliga@gmail.com"><img width="48" height="48" src="https://img.icons8.com/fluency/48/gmail.png"/></a>
            <a href="https://www.linkedin.com/in/florin-emanuel-todor-gliga/"><img width="48" height="48" src="https://img.icons8.com/color/48/linkedin.png"/></a>
            <a href="https://www.instagram.com/florintodor_/"><img width="48" height="48" src="https://img.icons8.com/fluency/48/instagram-new.png"/></a>
        </p>
    </div>

</body>
</html>
