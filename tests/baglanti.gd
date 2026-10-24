extends SceneTree
## Sunucuya sadece ENet bağlantısı kurup çıkar (hesap açmaz, kayda dokunmaz).
## Kullanım: godot --headless --path . --script tests/baglanti.gd -- ADRES [PORT]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var host := args[0] if args.size() > 0 else "127.0.0.1"
	var port := int(args[1]) if args.size() > 1 else 7777
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(host, port) != OK:
		print("BAĞLANTI BAŞLATILAMADI")
		quit(1)
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)    # 0.7+ sunucularla aynı ayar
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 6000:
		peer.poll()
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			print("BAĞLANDI: %s:%d (%d ms)" % [host, port, Time.get_ticks_msec() - start])
			peer.close()
			quit(0)
			return
		OS.delay_msec(20)
	print("ZAMAN AŞIMI: %s:%d sunucusuna ulaşılamadı" % [host, port])
	quit(1)
