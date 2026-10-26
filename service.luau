--!nonstrict

--- EN: Noctalia background-service entry; starts the MPD poller and forwards update ticks.
--- ES: Entrada del servicio en segundo plano de Noctalia; inicia el sondeo MPD y reenvía los ticks.

local poller = require("./lib/mpd/poller.luau")

--- EN: Refreshes MPD state when Noctalia's service interval elapses; returns nothing.
--- ES: Actualiza el estado MPD cuando vence el intervalo del servicio; no devuelve nada.
function update()
  poller.update()
end