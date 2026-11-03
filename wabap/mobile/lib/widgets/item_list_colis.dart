import 'package:flutter/material.dart';
import 'package:wabap/models/Colis.dart';
import 'package:wabap/widgets/item_colis.dart';
import 'package:wabap/screen/tournee_map_group_screen.dart';
import 'package:wabap/models/Status.dart';

class GroupColisItem extends StatefulWidget {
  final List<Colis> colisList;
  final String tourneeName;

  const GroupColisItem({super.key, required this.colisList, this.tourneeName = "Validation des colis"});

  @override
  GroupColisItemState createState() => GroupColisItemState();
}

class GroupColisItemState extends State<GroupColisItem> {
  late String tourneeId;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // Extracting tourneeId from the first Colis object in the list
    if (widget.colisList.isNotEmpty) {
      tourneeId = widget.colisList[0].tournee.id;
    } else {
      // Handle the case when colisList is empty if needed
      throw ArgumentError("Colis list cannot be empty.");
    }
  }

  @override
  Widget build(BuildContext context) {
    Colis firstColis = widget.colisList[0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 Main Clickable Row (Navigates to Details Page)
        InkWell(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => TourneeMapGroupScreen(
                colisList: widget.colisList,
                tourneeName: widget.tourneeName,
              ),
            ));
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                if (!_isExpanded)
                  BoxShadow(
                    color: Colors.grey.withValues(red: 128, green: 128, blue: 128, alpha: 77),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                // ⬇️ Column with Arrow + "Voir Plus"
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.blue,
                      ),
                      onPressed: _toggleExpansion,
                    ),
                    GestureDetector(
                      onTap: _toggleExpansion, // Clicking "Voir Plus" expands the list
                      child: Text(
                        _isExpanded ? "Réduire" : "Voir Plus",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),

                // 📌 Subscriber Name & Number of Colis
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Abonné
                          Expanded(
                            flex: 2,
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: const TextStyle(fontSize: 16, color: Colors.black),
                                children: [
                                  TextSpan(
                                    text: firstColis.owner == "francaise des jeux" ? "PDV : " : "Abonné : ",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: firstColis.subscriber?.name ?? "Inconnu"),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),

                          // Nb Colis
                          Expanded(
                            flex: 1,
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 16, color: Colors.black),
                                children: [
                                  const TextSpan(
                                    text: "Nb Colis : ",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: "${widget.colisList.length}"),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Address
                      Text(
                        firstColis.address,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(width: 30, _getIconByStatus()))
              ],
            ),
          ),
        ),

        // 📦 Expanded List of Colis
        if (_isExpanded)
          Column(
            children: widget.colisList.map((colis) => ColisItem(colis: colis)).toList(),
          ),
      ],
    );
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  String _getIconByStatus() {
    int nbIssue = 0;
    int nbCompleted = 0;
    bool isProgress = false;
    for (int i = 0; i < widget.colisList.length; i++) {
      if (widget.colisList[i].lastStatus.status == Status.COMPLETED) {
        nbCompleted++;
      } else if (widget.colisList[i].lastStatus.status == Status.IN_PROGRESS) {
        isProgress = true;
        break;
      } else if (widget.colisList[i].lastStatus.status == Status.ISSUE) {
        nbIssue++;
      }
    }
    Status status = Status.PENDING;
    if (isProgress) {
      status = Status.IN_PROGRESS;
    } else if (nbCompleted == widget.colisList.length) {
      status = Status.COMPLETED;
    } else if (nbIssue > 0) {
      status = Status.ISSUE;
    }

    switch (status) {
      case Status.COMPLETED:
        return "assets/images/check_on.png";
      case Status.ISSUE:
        return "assets/images/nok.png";
      case Status.IN_PROGRESS:
        return "assets/images/progress.png";
      case Status.PENDING:
        return "assets/images/check_off.png";
      default:
        return "assets/images/check_off.png";
    }
  }
}
