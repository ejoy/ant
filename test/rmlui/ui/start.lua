function start()
    console.log(document)
    console.log(document:getElementById "start".ownerDocument)
    document:getElementById "start".style.color = "red"
end

function load()
    document:getElementById "test":addEventListener("click", function()
        console.log('click')
    end)
end
