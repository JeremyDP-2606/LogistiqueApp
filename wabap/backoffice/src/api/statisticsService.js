import { API, graphqlOperation } from "@aws-amplify/api";
import { listSubscribers } from "@/graphql/queries";
import { listTourneesWithColis } from "@/api/queries";
import { getUsers } from "@/api/userService";


// Service to fetch tournees
export const fetchTournees = async (limit = 100) => {
  try {
    const currentMonth = new Date().toISOString().slice(0, 7);
    const tourneesData = await API.graphql(
      graphqlOperation(listTourneesWithColis, {
        filter: {
          createdAt: {
            beginsWith: currentMonth
          }
        },
        limit: limit,
      })
    );
    return tourneesData.data.listTournees.items ?? [];
  } catch (error) {
    console.error(">>> Error : SERVICE Tournees", error);
    throw new Error("Erreur de chargement des tournées");
  }
};

// Service to fetch subscribers
export const fetchSubscribers = async () => {
  try {
    const resultat = await API.graphql(
      graphqlOperation(listSubscribers, {
        limit: 100
      })
    );
    const currentMonth = new Date().toISOString().slice(0, 7);
    const filteredSubscribers = resultat.data.listSubscribers.items.filter(subscriber =>
      subscriber.createdAt.startsWith(currentMonth)
    );
    return {
      subscribers: filteredSubscribers,
      nextToken: resultat.data.listSubscribers.nextToken
    };
  } catch (error) {
    throw new Error(`Erreur de chargement des abonnés: ${error.message}`);
  }
};

// Service to fetch livreurs
export const fetchLivreurs = async () => {
  try {
    const users = await getUsers();
    const currentMonth = new Date().toISOString().slice(0, 7);

    const livreursData = await Promise.all(
      users.map(async (user) => {
        const sub = user.Attributes.find(attr => attr.Name === "sub").Value;
        const tourneesData = await API.graphql(
          graphqlOperation(listTourneesWithColis, {
            filter: {
              livreurID: {
                eq: sub,
              },
              createdAt: {
                beginsWith: currentMonth
              }
            },
          })
        );
        console.log("tournees", tourneesData.data.listTournees)
        const tournees = tourneesData.data.listTournees.items;

        return {
          ...user,
          sub,
          nbTournees: tournees.length,
          nbColisCompleted: tournees
            .flatMap(t => t.colis.items)
            .filter(colis => colis.lastStatus.status === "COMPLETED").length,
          nbColisPending: tournees
            .flatMap(t => t.colis.items)
            .filter(colis => colis.lastStatus.status === "PENDING").length,
        };
      })
    );

    return livreursData;
  } catch (error) {
    console.error("Erreur lors de la récupération des livreurs", error);
    throw new Error("Erreur lors de la récupération des livreurs");
  }
};

// Utility functions to compute statistics
export const computeCompletedDeliveries = (tournees) => {
  return tournees.filter(t =>
    t.colis.items.every(colis => colis.lastStatus.status === "COMPLETED")
  ).length;
};

export const computePendingDeliveries = (tournees) => {
  return tournees.filter(t =>
    t.colis.items.every(colis => colis.lastStatus.status === "PENDING")
  ).length;
};

export const computeSubscribersDelivered = (tournees) => {
  const deliveredSubscribers = new Set();

  tournees.forEach(t => {
    t.colis.items.forEach(colis => {
      if (colis.lastStatus.status === "COMPLETED" && colis.subscriberColisId !== undefined) {
        deliveredSubscribers.add(colis.subscriberColisId);
      }
    });
  });

  return deliveredSubscribers.size;
};

export const computePackagesDelivered = (tournees) => {
  let count = 0;

  tournees.forEach(t => {
    t.colis.items.forEach(colis => {
      if (colis.lastStatus.status === "COMPLETED") {
        count++;
      }
    });
  });

  return count;
};
