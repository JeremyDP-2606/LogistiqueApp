import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wabap/models/ModelProvider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wabap/util.dart';
import 'package:wabap/screen/preuve_livraison/colis_pickup_process_screen.dart';
import 'package:wabap/models/Status.dart';

class TourneeMapGroupScreen extends StatefulWidget {
  final List<Colis> colisList;
  final String tourneeName;
  const TourneeMapGroupScreen({Key? key, required this.colisList, this.tourneeName = "Validation des colis"}) : super(key: key);

  factory TourneeMapGroupScreen.fromColisList({
    Key? key,
    required List<Colis> colisList,
  }) {
    if (colisList.isEmpty) {
      throw ArgumentError("Colis list cannot be empty.");
    }

    return TourneeMapGroupScreen(
      key: key,
      colisList: colisList,
    );
  }

  @override
  TourneeMapGroupScreenState createState() => TourneeMapGroupScreenState();
}

class TourneeMapGroupScreenState extends State<TourneeMapGroupScreen> {
  late String tourneeId;
  late List<String> colisIds;
  final Completer<GoogleMapController> _controller = Completer();
  bool areColisValidable = false;

  @override
  void initState() {
    super.initState();
    // Extracting `tourneeId` and `colisIds` from the first `Colis` in the list
    if (widget.colisList.isNotEmpty) {
      tourneeId = widget.colisList[0].tournee.id; // Extract first colis' tourneeId
      colisIds = widget.colisList.map((colis) => colis.id).toList(); // Extract all colis IDs

      List<Status> validableStatus = [Status.IN_PROGRESS, Status.PENDING, Status.PICKED_UP];
      for(int i =0; i < widget.colisList.length; i++){
        if(validableStatus.contains(widget.colisList[i]?.lastStatus.status)){
        areColisValidable = true;
        break;
        }
      }
    } else {
      // Handle the case when colisList is empty
      throw ArgumentError("Colis list cannot be empty.");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.colisList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.tourneeName)),
        body: const Center(child: Text("Aucun colis disponible")),
      );
    }

    Colis firstColis = widget.colisList[0];
    LatLng initialPosition = LatLng(firstColis.latitude, firstColis.longitude);

    return Scaffold(
      appBar: AppBar(title: Text(widget.tourneeName)),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: initialPosition, zoom: 14),
              markers: widget.colisList
                  .map((colis) => Marker(
                markerId: MarkerId(colis.id),
                position: LatLng(colis.latitude, colis.longitude),
              ))
                  .toSet(),
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.person, size: 18, color: Colors.black54),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            "${firstColis.owner == "francaise des jeux" ? "PDV" : "Abonné"} : ${firstColis.subscriber?.name ?? "Inconnu"}  |  Nb Colis : ${widget.colisList.length}",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(firstColis.address, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
                    if (firstColis.subscriber?.phone1 != null || firstColis.subscriber?.phone2 != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                            "Tél : ${firstColis.subscriber?.phone1 ?? ""}${firstColis.subscriber?.phone1 != null && firstColis.subscriber?.phone2 != null ? " / " : ""}${firstColis.subscriber?.phone2 ?? ""}"),
                      ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                          side: const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      onPressed: () async {
                        String googleUrl =
                            'https://www.google.com/maps/search/?api=1&query=${firstColis.latitude},${firstColis.longitude}';
                        if (await canLaunchUrlString(googleUrl)) {
                          await launchUrlString(googleUrl, mode: LaunchMode.externalApplication);
                        } else {
                          throw 'Unable to open the map.';
                        }
                      },
                      child: const Text("Itinéraire", style: TextStyle(color: Colors.blue, fontSize: 18)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      ),
                      onPressed: !areColisValidable ? null : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PackageProcessScreen(
                              tourneeId: tourneeId,
                              isDeliveringPhase: true,
                              listColisToDeliver: widget.colisList,
                            ),
                          ),
                        );
                      },
                      child: const Text("Valider les colis", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
