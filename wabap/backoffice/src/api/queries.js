export const getMission = /* GraphQL */ `
  query GetMission($id: ID!) {
    getMission(id: $id) {
      createdAt
      daysOfWeek
      id
      livreurID
      name
      owner
      startLatitude
      startLongitude
      startName
      startTime
      startTimeZone
      generateDayBefore
      deliveryChecking
      subscribers(limit: 200) {
        nextToken
        items {
          name
          id
          secteur
          address
        }
      }
      inscriptions(limit: 200) {
        nextToken
        items {
          id
          livreurID
          createdAt
        }
      }
    }
  }
`;

export const listMissionsWithSub = /* GraphQL */ `
  query ListMissions(
    $filter: ModelMissionFilterInput
    $limit: Int
    $nextToken: String
  ) {
    listMissions(filter: $filter, limit: $limit, nextToken: $nextToken) {
      items {
        id
        name
        subscribers(limit: 200) {
          nextToken
          items {
            id
          }
        }
        livreurID
        startName
        startLongitude
        startLatitude
        daysOfWeek
        generateDayBefore
        startTime
        startTimeZone
        inscriptions(limit: 200) {
          nextToken
          items {
            id
          }
        }
        createdAt
        updatedAt
        owner
        __typename
      }
      nextToken
      __typename
    }
  }
`;

export const tourneesByDateWithColis = /* GraphQL */ `
  query ByMissionOrderDate(
    $missionTourneeId: ID!
    $createdAt: ModelStringKeyConditionInput
    $sortDirection: ModelSortDirection
    $filter: ModelTourneeFilterInput
    $limit: Int
    $nextToken: String
  ) {
    byMissionOrderDate(
      missionTourneeId: $missionTourneeId
      createdAt: $createdAt
      sortDirection: $sortDirection
      filter: $filter
      limit: $limit
      nextToken: $nextToken
    ) {
      items {
        id
        name
        status
        livreurID
        missionTourneeId
        createdAt
        updatedAt
        distance
        duree
        colis(limit: 200) {
          items {
            lastStatus {
              id
              status
            }
            distance
            duration
          }
          nextToken
          __typename
        }
        __typename
      }
      nextToken
      __typename
    }
  }
`;

export const listTourneesWithColis = /* GraphQL */ `
  query ListTournees(
    $filter: ModelTourneeFilterInput
    $limit: Int
    $nextToken: String
  ) {
    listTournees(filter: $filter, limit: $limit, nextToken: $nextToken) {
      items {
        id
        status
        livreurID
        createdAt
        updatedAt
        missionTourneeId
        colis(limit: 200) {
          items {
            lastStatus {
              id
              status
            }
            subscriberColisId
          }
          nextToken
          __typename
        }
        __typename
      }
      nextToken
      __typename
    }
  }
`;


export const byTourneeOrderPosition = /* GraphQL */ `
  query ByTourneeOrderPosition(
    $tourneeColisId: ID!
    $position: ModelIntKeyConditionInput
    $sortDirection: ModelSortDirection
    $filter: ModelColisFilterInput
    $limit: Int
    $nextToken: String
  ) {
    byTourneeOrderPosition(
      tourneeColisId: $tourneeColisId
      position: $position
      sortDirection: $sortDirection
      filter: $filter
      limit: $limit
      nextToken: $nextToken
    ) {
      items {
        id
        tourneeColisId
        position
        polyline
        distance
        duration
        createdAt
        updatedAt
        subscriberColisId
        subscriberName
        latitude
        longitude
        address
        subscriber {
          id
          name
          numabo
          phone1
          phone2
          instructions
        }
        lastStatus {
          id
          status
          createdAt
        }
        __typename
      }
      nextToken
      __typename
    }
  }
`;


export const subscriberOrderNameWithMission = /* GraphQL */ `
  query SubscriberOrderName(
    $type: String!
    $name: ModelStringKeyConditionInput
    $sortDirection: ModelSortDirection
    $filter: ModelSubscriberFilterInput
    $limit: Int
    $nextToken: String
  ) {
    subscriberOrderName(
      type: $type
      name: $name
      sortDirection: $sortDirection
      filter: $filter
      limit: $limit
      nextToken: $nextToken
    ) {
      items {
        id
        name
        address
        numabo
        phone1
        phone2
        secteur
        instructions
        longitude
        latitude
        type
        unsubscribed
        createdAt
        updatedAt
        missionSubscribersId
        mission {
          id
          name
        }
        owner
        __typename
      }
      nextToken
      __typename
    }
  }
`;


export const bySubscriberOrderDateWithTournee = /* GraphQL */ `
  query BySubscriberOrderDate(
    $subscriberColisId: ID!
    $createdAt: ModelStringKeyConditionInput
    $sortDirection: ModelSortDirection
    $filter: ModelColisFilterInput
    $limit: Int
    $nextToken: String
  ) {
    bySubscriberOrderDate(
      subscriberColisId: $subscriberColisId
      createdAt: $createdAt
      sortDirection: $sortDirection
      filter: $filter
      limit: $limit
      nextToken: $nextToken
    ) {
      items {
        id
        tourneeColisId
        subscriberColisId
        createdAt
        position
        lastStatus {
          id
          status
        }
        polyline
        distance
        duration
        address
        longitude
        latitude
        subscriberName
        updatedAt
        tournee {
          id
          name
          livreurID
        }
        __typename
      }
      nextToken
      __typename
    }
  }
`;


export const byLivreurOrderDate = /* GraphQL */ `
  query ByLivreurOrderDate(
    $livreurID: ID!
    $createdAt: ModelStringKeyConditionInput
    $sortDirection: ModelSortDirection
    $filter: ModelTourneeFilterInput
    $limit: Int
    $nextToken: String
  ) {
    byLivreurOrderDate(
      livreurID: $livreurID
      createdAt: $createdAt
      sortDirection: $sortDirection
      filter: $filter
      limit: $limit
      nextToken: $nextToken
    ) {
      items {
        id
        name
        status
        startName
        startLongitude
        startLatitude
        livreurID
        missionTourneeId
        createdAt
        distance
        duree
        nbColis
        updatedAt
        colis(limit: 200) {
          items {
            lastStatus {
              id
              status
            }
            distance
            duration
          }
          nextToken
          __typename
        }
        __typename
      }
      nextToken
      __typename
    }
  }
`;
